# CodeShip

Codeship is our Continuous Integration tool. Whenever your push commits to
GitHub, it triggers Codeship to run the full sets of tests.

We use the Codeship Basic rather than Codeship Pro, so keep that in mind if
you're looking up documentation.

Our test suite is fairly large, so we run it across three parallel machine
instances (Codeship calls these pipelines).

The build is only considered passed (or 'green') if all three pipelines pass.

In general, a failed ('red') build should never be merged into the master
branch, but there are a few exceptions:

TODO

[Continuous Integration]: https://en.wikipedia.org/wiki/Continuous_integration
