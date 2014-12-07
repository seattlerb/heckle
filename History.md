=== 2.0.0.b1 / 2012-10-02

* 1 major enhancement:

  * Hot damn! It works with ruby_parser!!! (phiggins)

* 1 minor enhancement:

  * 1.9 support! (phiggins)

* 3 bug fixes:

  * Fixed Ruby2Ruby usage (raggi)
  * Fixed dependencies so heckle doesn't use ruby_parser 3 and friends.
  * Fixed grammar in description.  Reported by Jean Lange.

=== 1.4.3 / 2009-06-23

* 2 minor enhancements:

  * Added autotest/heckle plugin
  * Skipping testing on 1.9

=== 1.4.2 / 2009-02-08

* 2 bug fixes:

  * Fixed Ruby2Ruby dependency and Ruby2Ruby references (name changed).
    Reported by David Chelimsky
  * Fix bug #11435 where [:iter, [:call], ...] would cause an endless
    loop.  Reported by Thomas Preymesser.

=== 1.4.1 / 2007-06-05

* 3 bug fixes:

  * Add zentest as a heckle dependency. Closes #10996
  * Fixed heckling of call with blocks.
  * Fix test_unit_heckler's test_pass? so it returns the result of the
    run rather than ARGV.clear

=== 1.4.0 / 2007-05-18

* 2 major enhancements:

  * Method calls are now heckled (by removal).
  * Assignments are now heckled (by value changing).

* 3 minor enhancements:

  * Added --focus to feel the Eye of Sauron (specify unit tests to run).
  * Specify nodes to be included/excluded in heckle with -n/-x.
  * Test only assignments with --assignments

=== 1.3.0 / 2007-02-12

* 1 major enhancement:

  * Unified diffs for mutatated methods

* 4 minor enhancements:

  * Now returns exit status 1 if failed.
  * Added a simple report at the end.
  * Runs are now sorted by method.
  * Autodetects rails and changes test_pattern accordingly.

* 2 bug fixes:

  * Aborts when an unknown method is supplied.
  * Escapes slashes in random regexps.

=== 1.2.0 / 2007-01-15

* 2 major enhancements:

  * Timeout for tests set dynamically and overridable with -T
  * Class method support with "self.method_name"

* 3 minor enhancements:

  * -b allows heckling of branches only
  * Restructured class heirarchy and got rid of Base and others.
  * Revamped the tests and reduced size by 60%.

* 1 bug fix:

  * Fixed the infinite loop caused by syntax errors

=== 1.1.1 / 2006-12-20

* 3 bug fixes:

  * Load tests properly when supplying method name.
  * Make sure random symbols have at least one character.
  * Removed all extra warnings from the unit tests. Consolidated and cleaned.

=== 1.1.0 / 2006-12-19

* 12 major enhancements:

  * Able to roll back original method after processing.
  * Can mutate numeric literals.
  * Can mutate strings.
  * Can mutate a node at a time.
  * Can mutate if/unless
  * Decoupled from Test::Unit
  * Cleaner output
  * Can mutate true and false.
  * Can mutate while and until.
  * Can mutate regexes, ranges, symbols
  * Can run against entire classes
  * Command line options!

=== 1.0.0 / 2006-10-22

* 1 major enhancement

  * Birthday!
