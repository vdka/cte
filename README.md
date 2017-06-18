# cte (Compile Time Execution)

A tiny language intended as a platform to test Compile Time Execution, as well as compiler architecture and polymorphism.

# Polymorphism

```
min := fn ($T: type, a: T, b: T) -> T {
  if a < b return a
  else return b
}

a : number = 5.0
b : number = 3.0
c := min(number, x, y)

username := "vdka"

d := min(number, username, c) // ERROR: Cannot convert value of type 'string' to expected argument type 'number'
```

`fn ($T: type, a: T, b: T) -> T` is a funciton that takes a type, type instances of that type and returns an instance of that type.
