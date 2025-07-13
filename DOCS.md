# Capri Language Documentation

Capri is a clean, expressive scripting language inspired by Lua, Zig and modern language design principles. Capri introduces a few unique features while keeping the learning curve low.

---

## Table of Contents

* [Values and Types](#values-and-types)
* [Variables](#variables)
* [Control Flow](#control-flow)
* [Loops and Ranges](#loops-and-ranges)
* [Box Structure](#box-structure)
* [Function Call Syntax](#function-call-syntax)
* [Builtins](#builtings)

---

## Values and Types

Capri has the following basic types:

* `Boolean` — `true` and `false`
* `Number` — floating point numbers
* `String` — double-quoted string values
* `Box` — a dictionary data structure (like Lua tables), written with `[]`
* `Function` — first-class anonymous or named functions
* `Nothing` — represents absence of a value

---

## Variables

```capri
mut a = 2
a = a + 1
```

Mutable variables are declared with `mut`. Reassignment is allowed without redeclaring.

---

## Control Flow

### If / Else

```capri
if x > 10 {
  @print("Big")
} elif x > 5 {
  @print("Medium")
} else {
  @print("Small")
}
```

---

## Loops and Ranges

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

---

## Branching

```capri
If entity.alive |value| {
    @print("Entity alive!")
} else {
    @print("I 've got some bad news about " .. entity.name)
}
```

As you can notice Capri uses zig-like capture.

Parentheses are not enforced. Only {} are.

## Box Structure

Boxes are the core data structure in Capri, supporting both arrays and maps:

```capri
mut colors = ["red", "green", "blue"]
mut user = [name = "Luna", age = 27]
```

Access:

```capri
@print(colors.0)       // "red"
@print(user.name)      // "Luna"
```

Set:

```capri
user.age = 28
colors.3 = "purple"
```

Nested Boxes:

```capri
mut config = [
  window = [width = 800, height = 600],
  fullscreen = true
]
```

### Comma-Free Syntax

Capri allows you to omit commas between elements in a box as long as the structure remains unambiguous. This can improve readability and reduce visual clutter:

```capri
mut palette = [
  "red"
  "green"
  "blue"
]

mut person = [
  name = "Aria"
  age = 30
  job = "Engineer"
]
```

Both comma and comma-free styles are valid but can't be mixed.

```capri
mut palette = [
  "red"
  "green",
  "blue"
  "yellow"
  "black",
  "white,
]
```

**This is not valid!**

---

## Function Call Syntax

Capri functions can be called with or without parentheses. This applies to both user-defined and built-in functions:

```capri
say_hello("Capri")
say_hello "Capri"
```

Arguments may also be comma-free when clarity allows:

```capri
@print "Hello" "World"
draw_square 0 0 100 200 [1 0 0] //draw a red square 
```

Use whatever you think is more readable.

---

Here’s a new section for built-in functions and constants with the `@` prefix for Capri:

---

## Built-in Functions and Constants

Capri includes a set of built-in functions and constants, all prefixed with `@` for easy identification:

### Common Built-ins

| Name        | Description                     | Example                   |
| ----------- | ------------------------------- | ------------------------- |
| `@print`    | Prints values to the console    | `@print "Hello, Capri"`   |
| `@floor`    | Returns the floor of a number   | `@floor 3.7  // 3`        |
| `@ceil`     | Returns the ceiling of a number | `@ceil 3.2   // 4`        |
| `@pi`       | Mathematical constant π         | `radius * 2 * @pi`        |
| `@tostring` | Converts a value to a string    | `@tostring 123  // "123"` |
| `@tonumber` | Converts a string to a number if possible. Else it returns _Nothing_ | `@tonumber '123'  // 123` |
| `@assert` | Asserts that a condition is true. Else it stops the program and prints the message. | `@assert user.age > 0  // "Assertion failed: Age must be positive"` |
... | more to come! | ...

### Usage

Built-ins can be called with or without parentheses, and support comma-free arguments when unambiguous:

```capri
@print "Radius:" radius
area = @pi * radius * radius
floor_value = @floor radius
```

---

Capri is a work-in-progress language focused on clarity and flow. Its features are designed to feel intuitive and enable expressive, elegant code. Stay tuned for updates and expanded standard library features.
