Serialize All The Things
========================

satt is a "pre-serializer", primarily for Ruby objects. It maps objects
to "primitive" data types which can be serialized using MessagePack.

This is a small toy project of mine, nothing to be used in real-world
projects. I basically tried to reimplement the core features of Ruby Marshal.

Usage
-----
* ```gem install satt``` (https://rubygems.org/gems/satt)
* ```require "satt"```
* ```msg = Satt.dump(obj)```
* ```obj = Satt.load(msg)```

Features
--------
* Ruby objects are encoded using only "primitive" objects which are supported by MessagePack.
* Support for circular references and self-referential objects.
* Instances of ```NilClass```, ```Fixnum```, ```Float```, ```TrueClass```, ```FalseClass```,
  ```Symbol```, ```Bignum``` and ```BigDecimal``` are stored as value types. All other objects (including
  instances of ```Array```, ```Hash```, ```String```) are encoded as reference types,
  meaning that if you serialize a structure with more than one reference to some instance
  of one of those types, the encoding will take note of that.
  Example: ```s = "foo"; arr = [ s, s ]```. If you serialize ```arr``` and load it again,
  the resulting array will contain that same ```String``` object twice (note that this
  behaviour is the same as with Ruby Marshal, but different as with JSON).

Shortcomings
------------
* Instances of ```Binding```, ```IO```, ```Proc```, ```Class``` cannot be serialized.
* A Ruby object is identified by the name of it's class and by it's instance variables.
  The flags of a Ruby object (tainted, frozen, etc.) are not stored and will get lost
  during serialization. The same goes for Eigenclasses / Singleton classes and dynamically
  added methods, etc.
* Although being a lot faster than YAML, it's still considerably slower than Marshal.
* In principle, this same idea can be used with other serializers as well. However, JSON
  for example does not support hash keys which are instances of classes other than ```String```.
  If your object contains a hash like this, you will run into problems.

Speed
-----
Some very naive and probably not super meaningful benchmarks (see ```benchmark.rb```,
Psych denotes one of Ruby's YAML implementations):

```
                   user     system      total        real

Psych          3.590000   0.250000   3.840000 (  3.866077)
Psych_dump     1.660000   0.000000   1.660000 (  1.665416)
Psych_load     1.660000   0.170000   1.830000 (  1.855108)

Marshal        0.090000   0.000000   0.090000 (  0.094105)
Marshal_dump   0.040000   0.000000   0.040000 (  0.040213)
Marshal_load   0.050000   0.000000   0.050000 (  0.044659)

Satt           0.700000   0.000000   0.700000 (  0.701690)
Satt_dump      0.330000   0.000000   0.330000 (  0.336044)
Satt_load      0.290000   0.000000   0.290000 (  0.284530)
```
