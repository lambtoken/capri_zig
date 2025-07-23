# Capri Language Documentation

Capri is a simple, expressive scripting language. It introduces a few unique features while keeping the learning curve low.

---

## Table of Contents

* [Values and Types](#values-and-types)
* [Variables](#variables)
* [Branching](#branching)
* [Loops and Ranges](#loops-and-ranges)
* [Bundle Structure](#bundle-structure)
* [Function Definition](#function-definition)
* [Function Call Syntax](#function-call-syntax)
* [Builtins](#builtin-function)

---

## Values and Types

Capri has the following basic types:

* `Boolean` — `true` and `false`
* `Number` — 64 bit floating point numbers
* `String` — single or double quoted string values
* `Array` — a vector-like data structure of any type, written with `[]`
* `Struct` — a hashmap data structure, written with `{}` - to replace need for bundles
* `Function` — first-class anonymous or named functions
* `Reference`& - for referencing primitives by address
* `FileHandle` - used for working with files
* `Nothing` — nothing, absence of a value

Type of any data can be checked with @type builtin. It returns type as a string: 'boolean', 'number', 'string', 'array', 'struct , 'function', 'reference', 'file' or 'nothing'

---

## Variables

```capri
mut a = 2
a = a + 1
```

Mutable variables are declared with `mut`. Reassignment is allowed without redeclaring.

---

## Branching

### If / Else

```capri
if x > 10 {
  @print("Big")
} else if x > 5 {
  @print("Medium")
} else {
  @print("Small")
}
```

Parentheses are not enforced. Only {} are.


**Capture**

```capri
If entity.alive |value| {
    @print("Entity alive!")
} else {
    @print("I 've got some bad news about " .. entity.name)
}
```

As you can see Capri uses zig-like capture.


---

## Loops and Ranges

### While loop

```capri
while true {
    @println("I will not fake rabies")
}

### For Loop (Range)

```capri
for 1..5 |i| {
  print(i)
}
```

### Custom Ranges

```capri
for 0..10 |i| { ... }     // 0 to 10 inclusive
for 10.. |i| { ... }      // down to 0
for .. |i| { ... }        // zero-iteration loop (evaluates to nothing)
```

Ranges can therefore also be used for creating empty bundles like:

```capri
squares = .. // same as squares = {}

for i in 1..10 {
    @push(squares, @pow(i, 2))
}

@print(squares) // 1, 4, 9, 16 ...

```


## Bundle Structure (experimental)


Bundles are the core data structure in Capri, supporting both arrays and maps:

```capri
mut colors = {"red", "green", "blue"}
mut user = {name = "Luna", age = 27}
```

Access:

```capri
@print(colors[0])       // "red"
@print(user.name)      // "Luna"
```

Set:

```capri
user.age = 28
colors[3] = "purple"
@push(colors, "cyan")
@insert(colors, @len(colors), "yellow")
```

Removing items:

```capri
colors[1] = nothing
@pop(colors)
@remove(colors, 3)

```



Nested Bundles:

```capri
mut config = {
  window = {width = 800, height = 600},
  fullscreen = true
}
```

Bundles come with predifined lifecycle callbacks.

    - __new
    - __destroy
    - __tostring

---

## Function Definition

In Capri functions can be defined like this:

```capri
fun printer(text) {
    @println(text)
}
```

---

## Function Call Syntax

Capri functions follow the standard way of invoking.

```capri
say_hello("Capri")
```

---


## Builtin Function

Capri includes a set of builtin functions and constants, all prefixed with `@` for easy identification:



## `@args`

```my-lang
@args() -> [string]
```

Returns the list of command-line arguments passed to the program.

**Example:**

```my-lang
args = @args()
@println(args[0])
```

---

## `@print`

```my-lang
@print(value: any) -> void
```

Prints the given value to standard output without a newline.

**Example:**

```my-lang
@print("Hello, ")
@print("world!")
```

---

## `@println`

```my-lang
@println(value: any) -> void
```

Prints the given value followed by a newline.

**Example:**

```my-lang
@println("Hello")
@println(123)
```

---

## `@prompt`

```my-lang
@prompt(message: string) -> string
```

Displays a message and waits for user input.

**Example:**

```my-lang
name = @prompt("Enter your name: ")
@println("Hello, " + name)
```

---

## `@assert`

```my-lang
@assert(condition: bool, message: string) -> void
```

Crashes if the condition is false and prints the message.

**Example:**

```my-lang
@assert(1 + 1 == 2, "Should never happen.")
```

---

## `@error`

```my-lang
@error(message: string) -> void
```

Terminates the program with the given error message.

**Example:**

```my-lang
@error("Something went wrong")
```

---

## `@len`

```my-lang
@len(value: [any]) -> number
```

Returns the length of an array or string.

**Example:**

```my-lang
@println(@len("hello"))     // 5
@println(@len([1,2,3,4]))    // 4
```

---

## `@split`

```my-lang
@split(input: string, delimiter: string) -> [string]
```

Splits the input string into a list of strings by delimiter. If not provided, default delimeter is " ".

**Example:**

```my-lang
parts = @split("a,b,c", ",")
@println(parts[1]) // "b"
```

---

## `@trim`

```my-lang
@trim(input: string) -> string
```

Trims leading and trailing whitespace.

**Example:**

```my-lang
@println(@trim("  hello  ")) // "hello"
```

---

## `@toUpper`

```my-lang
@toUpper(input: string) -> string
```

Converts all characters in the string to uppercase.

**Example:**

```my-lang
@println(@toUpper("abc")) // "ABC"
```

---

## `@toLower`

```my-lang
@toLower(input: string) -> string
```

Converts all characters in the string to lowercase.

**Example:**

```my-lang
@println(@toLower("HELLO")) // "hello"
```

---

## `@toNum`

```my-lang
@toNum(input: string) -> number
```

Parses a string into a number. If fails, returns `nothing`.

**Example:**

```my-lang
n = @toNum("42")
@println(n + 1) // 43

nan = @toNum("3d")
@println(nan) // nothing
```

---

## `@toStr`

```my-lang
@toStr(value: any) -> string
```

Converts a value to its string representation.

**Example:**

```my-lang
@println(@toStr(123)) // "123"
```

---

## `@push`

```my-lang
@push(list: [any], value: any) -> void
```

Appends an element to the list.

**Example:**

```my-lang
let items = [1, 2]
@push(items, 3)
@println(items) // [1, 2, 3]
```

---

## `@pop`

```my-lang
@pop(list: [any]) -> any
```

Removes and returns the last element of the list.

**Example:**

```my-lang
let items = [1, 2, 3]
let last = @pop(items)
@println(last) // 3
```

---

## `@insert`

```my-lang
@insert(list: [any], index: number, value: any) -> void
```

Inserts a value at the specified index.

**Example:**

```my-lang
let items = [1, 3]
@insert(items, 1, 2)
@println(items) // [1, 2, 3]
```

---

## `@remove`

```my-lang
@remove(list: [any], index: number) -> void
```

Removes the element at the specified index.

**Example:**

```my-lang
let items = [1, 2, 3]
@remove(items, 1)
@println(items) // [1, 3]
```

---

## `@pi`

```my-lang
@pi: const number
```

Mathematical constant π.

**Example:**

```my-lang
@println(@pi())
```

---

## `@e`

```my-lang
@e: const number
```

Mathematical constant e.

**Example:**

```my-lang
@println(@e())
```

---

## `@pow`

```my-lang
@pow(base: number, exponent: number) -> number
```

Raises `base` to the power of `exponent`.

**Example:**

```my-lang
@println(@pow(2, 3)) // 8
```

---

## `@sqrt`

```my-lang
@sqrt(x: number) -> number
```

Returns the square root of `x`.

**Example:**

```my-lang
@println(@sqrt(16)) // 4
```

---

## `@sin`

```my-lang
@sin(x: number) -> number
```

Returns the sine of `x` (radians).

**Example:**

```my-lang
@println(@sin(@pi / 2)) // 1
```

---

## `@cos`

```my-lang
@cos(x: number) -> number
```

Returns the cosine of `x` (radians).

**Example:**

```my-lang
@println(@cos(0)) // 1
```

---

## `@tan`

```my-lang
@tan(x: number) -> number
```

Returns the tangent of `x` (radians).

**Example:**

```my-lang
@println(@tan(0)) // 0
```

---

## `@round`

```my-lang
@round(x: number) -> number
```

Rounds to the nearest whole number.

**Example:**

```my-lang
@println(@round(2.7)) // 3
```

---

## `@floor`

```my-lang
@floor(x: number) -> number
```

Rounds down to the nearest whole number.

**Example:**

```my-lang
@println(@floor(2.7)) // 2
```

---

## `@ceil`

```my-lang
@ceil(x: number) -> number
```

Rounds up to the nearest whole number.

**Example:**

```my-lang
@println(@ceil(2.1)) // 3
```

---

## `@rand`

```my-lang
@rand() -> number
```

Returns a pseudorandom number between 0 and 1.

**Example:**

```my-lang
@println(@rand())
```

---

## `@randseed`

```my-lang
@randseed(seed: number) -> void
```

Sets the seed for the pseudorandom number generator.

**Example:**

```my-lang
@randseed(12345)
```

---

## `@time`

```my-lang
@time() -> number
```

Returns the current time in seconds since epoch.

**Example:**

```my-lang
@println(@time())
```

---

## `@map`

```my-lang
@map(list: [any], func: fun(any) -> any) -> [any]
```

Applies a function to each element of an array.

**Example:**

```my-lang
@map([1, 2, 3], fn(x) { x + 1 }) // [2, 3, 4]
```

---

## `@foldl`

```my-lang
@foldl(list: [any], init: any, func: fun(any, any) -> any) -> any
```

Reduces an array from the left.

**Example:**

```my-lang
@foldl([1, 2, 3], 0, fun(a, b) { a + b }) // 6
```

---

## `@foldr`

```my-lang
@foldr(list: [any], init: any, func: fn(any, any) -> any) -> any
```

Reduces an array from the right.

**Example:**

```my-lang
@foldr([1, 2, 3], 0, fun(a, b) { a + b }) // 6
```

---

## `@zip`

```my-lang
@zip(list1: [any], list2: [any]) -> [(any, any)]
```

Combines two lists into a list of pairs.

**Example:**

```my-lang
@zip([1, 2], ["a", "b"]) // [(1, "a"), (2, "b")]
```

---

## `@filter`

```my-lang
@filter(list: [any], predicate: fn(any) -> bool) -> [any]
```

Returns a list of elements that satisfy the predicate.

**Example:**

```my-lang
@filter([1, 2, 3, 4], fun(x) { x % 2 == 0 }) // [2, 4]
```

---

## `@any`

```my-lang
@any(list: [any], predicate: fun(any) -> bool) -> bool
```

Returns true if any element satisfies the predicate.

**Example:**

```my-lang
@any([1, 2, 3], fun(x) { x > 2 }) // true
```

---

## `@all`

```my-lang
@all(list: [any], predicate: fun(any) -> bool) -> bool
```

Returns true if all elements satisfy the predicate.

**Example:**

```my-lang
@all([2, 4], fun(x) { x % 2 == 0 }) // true
```

---

## `@scan`

```my-lang
@scan(list: [any], init: any, func: fun(any, any) -> any) -> {any}
```

Computes prefix results like a running total.

**Example:**

```my-lang
@scan([1, 2, 3], 0, fun(a, b) { a + b }) // [1, 3, 6]
```

---

## `@open`

```my-lang
@open(path: string, mode: string) -> FileHandle
```

Opens a file and returns a handle.

**Example:**

```my-lang
file = @open("test.txt", "r")
```

---

## `@read`

```my-lang
@read(file: FileHandle) -> string
```

Reads contents from a file.

**Example:**

```my-lang
let content = @read(file)
```

---

## `@write`

```my-lang
@write(file: FileHandle, data: string) -> void
```

Writes data to a file.

**Example:**

```my-lang
@write(file, "Hello")
```

---

## `@close`

```my-lang
@close(file: FileHandle) -> void
```

Closes a file handle.

**Example:**

```my-lang
@close(file)
```

---

## `@sleep`

```my-lang
@sleep(milisecond: number) -> void
```

Pauses execution for the specified duration.

**Example:**

```my-lang
@sleep(1000)
```

---

## `@winWidth`

```my-lang
@winWidth() -> number
```

Returns the width of the display or terminal.

**Example:**

```my-lang
@println(@winWidth())
```

---

## `@winHeight`

```my-lang
@winHeight() -> number
```

Returns the height of the display or terminal.

**Example:**

```my-lang
@println(@winHeight())
```

---

## `@clearScreen`

```my-lang
@clearScreen() -> void
```

Clears the screen output of the terminal.

**Example:**

```my-lang
@clearScreen()
```



---

Capri is a work-in-progress language. Stay tuned for updates and expanded standard library features.
