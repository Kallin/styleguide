# Rails Guidelines

* We use the [Squeel][squeel] gem, but it is no longer maintained.
  We are still deciding whether to remove it completely, or replace it
  with [baby_squeel][baby_squeel] – see [Slack discussion][slack_squeel].
  Regardless, we should avoid Squeel syntax when writing any _new_ code.

# Large Classes

We have two very large classes in the application: `PartnerLoan` and `Partner`.

As these are difficult to work with, we aim to avoid adding additional behaviour
to them. Often there is a better way. For example, you might first extract out
some of the existing behaviour into a new class, and then make the desired
change.

To learn more, you can read up on the Large Class smell, and some refactorings
to deal with it: [Refactoring: Ruby Edition, Ch. 3]

[squeel]: https://github.com/activerecord-hackery/squeel
[baby_squeel]: https://github.com/rzane/baby_squeel
[slack_squeel]: https://financeit.slack.com/archives/C024QMFSF/p1519847908000572
[Refactoring: Ruby Edition, Ch. 3]: https://www.safaribooksonline.com/library/view/refactoring-ruby-edition/9780321603968/ch03.html
