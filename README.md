# Memdump

Memdump is a set of (basic) tools to create and manipulate Ruby object dumps.

Since Ruby 2.1, ObjectSpace can be dumped in a JSON file that represents all
allocated objects and their relationships. It is a gold mine of information if
you want to understand why your application has that many objects and/or a
memory leak.

Processing methods are available as a library, or using the `memdump`
command-line tool. Just run `memdump help` for a summary of operations.

**NOTE** running memdump under jruby really reduces processing times... If you're using rbenv, just do

```
rbenv shell jruby-9.0.5.0
```

in the shell where you run the memdump commands.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'memdump'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install memdump


## Creating a memory dump

### Using rbtrace

The memdump command-line tool can connect to a process where
the [excellent rbtrace](https://github.com/tmm1/rbtrace) has been required. Just
start your Ruby application with `-r rbtrace`, e.g.

```
ruby -rrbtrace -S syskit run
```

and find out the process PID using e.g. top or ps (in the following, I assume
that the PID is 1234)

Memory dumps are then created with

```
memdump dump 1234 /tmp/mydump
```

Since `dump_all` requires very long, the rbtrace client will return before the
end of the dump with `*** timed out waiting for eval response`. Check your
application's output for a line saying `sendto(14): No such file or directory
[detaching]`

Additionally, you might want to enable allocation tracing, which adds to the
dump the line/file of the point where the object got allocated but is also very
costly from a performance point of view, do

```
memdump enable-allocation-trace 1234
```

### Manually

It is sometimes more beneficial to do the dumps in specific places
in your application, something the rbtrace method does not allow you to do. In
this case, create memory dumps by calling `ObjectSpace.dump_all`

~~~ ruby
require 'objspace'
File.open('/path/to/dump/file', 'w') do |io|
  ObjectSpace.dump_all(output: io)
end
~~~

Allocation tracing is enabled with

~~~ ruby
require 'objspace'
ObjectSpace.trace_objects_allocation_start
~~~

## Analyzing the dump

The first thing you will probably want to do is to run the replace-class command
on the dump. It replaces the class attribute, which in the original dump is the
reference to the class object, by the class name. This makes reading the dump a
lot easier.

```
memdump replace-class /tmp/mydump
```

The most basic analysis is done by running **stats**, which outputs the object
count by class. For memory leaks, the **diff** command allows you to output the
part of the graph that involves new objects (removing the
"old-and-not-referred-to-by-new")

Beyond that, I usually go back and forth between the memory dump and
[gephi](http://gephi.org), a graph analysis application. the **gml** command
allows to convert the memory dump into a graph format that gephi can import.
From there, use gephi's layouting and filtering algorithms to get an idea of the
most likely objects. Then, you can "massage" the dump using the **root_of**,
**subgraph_of** and **remove-node** commands to narrow the dump to its most useful
parts.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/doudou/memdump.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

