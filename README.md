## Sanguinius

`sanguinius` is a basic **scheme** interpreter written in `swift`. In order to build `sanguinius` from sources, the following are required:

* swift 2.2-dev

If all requirements are met, perform the following steps:

        swift build

You can run `sanguinius` by typing:

	.build/debug/sanguinius

inside the project directory.

### example
    
    > 1
    1
    > #t
    #t
    > 45 ; a comment
    45
    > #\c
    #\c
    > "asdf"
    "asdf"
    > (quote ())
    ()
    > (quote (0 . 1))
    (0 . 1)
    > (quote (0 1 2 3))
    (0 1 2 3)
    > (quote asdf)
    asdf
    > ^C

### changes

* v0.8   Added quoted form
* v0.7   Added symbols
* v0.6   Added pair and list literals
* v0.5   Support for the empty list literal
* v0.4   Added string literals
* v0.3   Added character literals
* v0.2   Added booleans
* v0.1   Support for integers
