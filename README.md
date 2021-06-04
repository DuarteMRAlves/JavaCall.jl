# JavaCall

Call Java programs from Julia.

## Dependencies
To be able to use this package, you first need to install its dependencies:
```Julia
julia> ]
(@v1.6) pkg> instantiate
```

## Usage
To use this package execute the following steps:
- Import the package
  ```Julia
  > using JavaCall
  ```
- Init the virtual machine
  ```Julia
  > JavaCall.init()
  ```
- Import the desired classes
  ```Julia
  > @jimport "java.lang.String"
  ```
- And run java code
  ```Julia
  > a = JString("Hello, ")
  > a = j_concat(a, JString("World!")
  > string(a)
  "Hello, World!"
  ```
