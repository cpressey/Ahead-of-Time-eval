Ahead-of-Time `eval`
====================

**Aggressive Constant Folding + `eval` = Hygienic Macros**

Motivation
----------

I'm writing this because basically every hygienic macro system I've
ever seen has struck me as _ad hoc_ and convoluted (just my opinion,
of course) and I wanted to present one that is coherent and
conceptually simple, merely as a counter-example, in the hope that
others might find it interesting (even if they don't necessarily
agree with my opinion).

Some prototype code can be found in [aot-eval.scm](aot-eval.scm) in this
repo; but it's buggy and incomplete, so for now it's probably best
to consider this to be just a write-up.

Background
----------

The definition of the Scheme programming language includes
a rule that essentially says

> If a procedure call can be replaced with a tail call without
> changing the meaning of the expression, it *must* be
> replaced with a tail cail.

In the Scheme report, this is called "proper tail recursion"
[[Footnote 1]](#footnote-1) and it is somewhat unusual,
as language implementation requirements go, in that it is an
operational rule rather than a semantic one; it
doesn't affect the result that the procedure computes, instead
it constrains the method by which the result is to be computed.

I mention this rule because in this article I would like to
consider a rule with a similarly operational character, which is:

> If the value of an expression can be computed ahead of time
> without changing the meaning of the expression, it *must*
> be computed ahead of time.

Since this is a kind of constant folding [[Footnote 2]](#footnote-2),
we could follow the example of "proper tail recursion" and call this
"proper constant folding"; however, that phrasing seems not quite fitting.
The situation here is slightly more complex.  So instead, we will
call this _aggressive constant folding_. [[Footnote 3]](#footnote-3)

In this article, I'd like to demonstrate that the combination of
aggressive constant folding together with an `eval` facility provides an
alternative to a macro system which is both conceptually simple and hygenic,
and has a number of other assorted benefits.

For the purpose of this demonstration, we will sketch a functional programming
language with these two features.  For concreteness, consider it to be
fundamentally based on Scheme, but much simplified.

Aggressive constant folding
---------------------------

Let's begin by giving a somewhat more rigorous definition for
what we've called aggressive constant folding.

Literals such as `1` and `"Hello, world!"` are constants.
A literal function, that is, a lambda expression
such as `(lambda (x) (* x x))`, is also a constant.

Built-in functions, such as the function represented by `*`,
are also constants.

If `f` is a constant function and `a1`, `a2`, ... `an` are constants,
then the function application `(f a1 a2 ... an)` can be
computed ahead of time, assuming the following things about f:

*   `f` is _referentially transparent_, i.e. evaluating `f`
    depends only on the arguments passed to it, and does
    not cause any side-effects; and
*   `f` is _always terminating_, i.e. evaluating `f` always
    returns a result after a finite time, for any choice of
    arguments passed to `f`.

(_How_ we determine whether `f` is referentially transparent
and always terminating is an altogether different matter.  There are several approaches
that can be taken.  The language can be designed to only be capable
of expressing such functions; the properties can be specified as part
of a type system; we can use abstract interpretation to conservatively infer these
properties; or we can simply assume that any function that is not
referentially transparent and always terminating will be marked as such by the
programmer and that any incorrect marking is a bug just like any other
bug.  Because there are so many choices, and they are in a sense irrelevant
to the main ideas here, examining any particular is outside the scope of this 
article.  For our demonstrations, we'll simply assume all the functions we are
working with are both referentially transparent and always terminating.)

There is a third constraint:

*   All variables inside `f`, apart from the formal parameters
    of `f` itself, are bound to constants.

Now, if `(f a1 a2 ... a2)` can be computed ahead of time, we do so,
then replace it (either conceptually or concretely) with the
constant value we obtained by doing so.

Once replaced, we may then consider whether the function
application containing this constant, is itself constant,
and so on recursively up the syntax tree.

That is the basic idea.

**TODO: there should really be a good example or two here.**

There are a few more details we could mention:

The property of being a constant is tracked in the scope
of identifiers used in the program.  That is to say, given a name,
we must know that that name is bound to a constant, in order to
treat it as a constant.  If we do not know this, we should err on
the side of safety and assume it does not refer to a constant.

The property of being constant can, and thus should, apply to some
common language constructs that aren't functions, especially the
more basic onces.  For example, in an `(if x t f)` expression,
`x` may be a constant; if `x` is a "truthy" constant then the
entire expression reduces to `t`, otherwise it reduces to `f`.

`quote` and `eval`
------------------

To demonstrate our point about hygienic macros, the language
will need an `eval` facility, and in order to have that, it will
need a way to represent program texts as data structures, which
feature as values in the semantics of programs in the language.

For concreteness we will call such values "phrases".

The conventional way to cast phrases in a language which we've already
said is similar to Scheme, is to say that phrases are list structures
containing sublists and atoms, and have a `quote` construct which
introduces literal phrases as expressions.

We note that a `quote` form is a constant.

Meanwhile, `eval` is a built-in function that takes a phrase and
an environment, and evaluates to the value that
that phrase would evaluate to in that environment.  Again,
this is very similar to Schemes's `eval`; the main difference
is that we shall have a slightly more nuanced idea of
"environment" (see below).

We note also that `eval` is a constant.  So, by the rules of
aggressive constant folding,

    (eval (quote (* 2 2)) std-env)

is a constant (the constant value `4`), under the assumption that
`std-env` is a value representing an environment (presumably
the "standard" environment) in which the symbol `*` is
bound to a suitable integer multiplication function.

Macros
------

Given all of the above, a macro is nothing more than a function that happens to
have been given constants as its actual parameters.  It will be
reduced to a constant ahead of time, which coincides perfectly
with the commonplace idea of what a macro is supposed to do.

Such "macros" also happen to "gracefully degrade" back into functions;
if not all actual parameters are constants, the function will not be applied
until the values of the non-constant parameters are known, i.e. at runtime.

In fact, aggressive constant folding by itself deprecates many use cases
for macros.  Instead of `#ifdef DEBUG`, for instance, we can simply define
`debug` as a function that returns a constant and use plain `if` tests on
it; we have a strong guarantee that this will all have been accounted for
ahead of time and will not appear in the code or impose any cost at runtime.

Many languages have more sophisticated macro systems, though, in terms of syntax,
where macros need not "look like" functions; they permit alternate syntax to be
employed when the macro is applied.  We can simulate that to a great degree
here using `quote`, to pass a phrase to the function.  The function then
calls `eval` on it.  Before doing so, it can transform the phrase in any way it
sees fit, since the phrase is simply a data structure.  The transformation,
and the `eval`, both happen ahead of time, so long as they only involve other
pieces of information known ahead of time (i.e. constants.)

Such manipulation is naturally hygienic.  This is because the environment passed
to `eval` is explicitly given, and only the bindings in that environment will be
used during the evaluation of `eval`.  Supplying only a standard environment,
which does not contain any bindings specific to the active program, makes it
impossible to capture such a binding during the evaluation of `eval`.

It also makes it possible to strategically subvert hygiene, by manipulating the
environment that is passed in so that it no longer resembles the "standard" one.

**TODO: there should really be more examples here.**

Related Work
------------

I have no idea how novel this is; it's so simple that I hardly expect that no one
has ever thought of it before; yet I haven't come across this arrangement of things
before.

Clearly it is related to constant folding; but constant folding is often considered
only as a compiler optimization, and not something that is specified by the language.

Clearly it is also related to partial evaluation; but partial evaluation usually
goes much further.  Partial evaluation generally aims at statically generating a
new function when *any* of its arguments are constant; while aggressive constant
folding only reduces the function to a constant when *all* of its arguments are
constant.

Clearly it is also related to hygienic macros, but I refer back to my opinion at the
beginning of the article.  Hygienic macro systems almost always seem to start with
conventional (unhygienic) macros and then patch them up so that they're hygienic.
This seems to approach the entire problem from a different angle, obviating the very
need for macros in some instances.

It also seems to be related to evaluation techniques for functional languages,
although my impression is that much of the existing work there is to support
more performant ways of implementing lazy languages.  Ahead-of-Time eval
addresses performance in much the same way macros do, but that is not their goal.

- - - -

#### Footnote 1

See, for example, section 3.5 of the
[Revised^5 Report on the Algorithmic Language Scheme](https://schemers.org/Documents/Standards/R5RS/).

#### Footnote 2

For more background on constant folding, see, for example, the
[Wikipedia article on Constant folding](https://en.wikipedia.org/wiki/Constant_folding),
though note that the Wikipedia article focuses on it as a compiler optimization,
rather than as a language specification rule as we're doing here.

#### Footnote 3

We also avoid the phrase "compile-time" as is technically inaccurate, as we might never actually
compile the given code; instead we say "ahead of time".
