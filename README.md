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

    > ^C

### changes

* v0.2   Added booleans
* v0.1   Support for integers

