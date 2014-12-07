= heckle

home :: http://ruby.sadi.st/Heckle.html
code :: https://github.com/seattlerb/heckle
rdoc :: http://seattlerb.rubyforge.org/heckle

== DESCRIPTION:

Heckle is unit test sadism(tm) at its core. Heckle is a mutation tester. It modifies your code and runs your tests to make sure they fail. The idea is that if code can be changed and your tests don't notice, either that code isn't being covered or it doesn't do anything.

It's like hiring a white-hat hacker to try to break into your server and making sure you detect it. You learn the most by trying to break things and watching the outcome in an act of unit test sadism.

== FEATURES/PROBLEMS:

* Mutates booleans, numbers, strings, symbols, ranges, regexes and branches (if, while, unless, until)
* Able to mutate entire classes, or individual methods
* Can not yet mutate class methods

== SYNOPSIS:

    % heckle -v Autotest

== REQUIREMENTS:

* ruby2ruby 1.1.2 or greater
* ParseTree 1.6.1 or greater

== INSTALL:

* sudo gem install heckle

== LICENSE:

(The MIT License)

Copyright (c) Ryan Davis, seattle.rb, and Kevin Clark

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
