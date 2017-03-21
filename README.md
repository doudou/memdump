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
ObjectSpace.trace_objects_allocations_start
~~~

## Basic analysis

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

Beyond, this analyzing the dump is best done through the interactive mode:

```
memdump interactive /tmp/mydump
```

will get you a pry shell in the context of the loaded MemoryDump object. Use
the MemoryDump API to filter out what you need. If you're dealing with big dumps,
it is usually a good idea to save them regularly with `#dump`.

One useful call to do at the beginning is #common_cleanup. It collapses the
common collections (Array, Set, Hash) as well as internal bookkeeping objects
(ICLASS, …). I usually run this, save the result and re-load the result (which
is usually significantly smaller).

After, the usual process is to find out which non-standard classes are
unexpectedly present in high numbers using `stats`, extract the objects from
these classes with `dump = objects_of_class('classname')` and the subgraph that
keeps them alive with `roots_of(dump)`

```
# Get the subgraph of all objects whose class name matches /Plan/ and export
# it to GML to process with Gephi (see below)
parent_dump, _ = roots_of(objects_of_class(/Plan/))
parent_dump.to_gml('plan-subgraph.gml')
```

Once you start filtering dumps, don't forget to simplify your life by `cd`'ing
in the context of the newly filtered dumps

Beyond that, I usually go back and forth between the memory dump and
[gephi](http://gephi.org), a graph analysis application. `to_gml` allows to
convert the memory dump into a graph format that gephi can import.  From there,
use gephi's layouting and filtering algorithms to get an idea of the shape of
the dump. Note that you need to first get a graph smaller than a few 10k of objects
before you can use gephi.

## Dump diffs

One powerful way to find out where memory is leaked is to look at objects that
got allocated and find the interface between the long-term objects and these
objects. memdump supports this by computing diffs.

Let's assume that we have a "before.json" and "after.json" dumps. Start an interactive
shell loading `before`.

```
memdump interactive before.json
```

Then, in the shell, let's load the after dump

```
> after = MemDump::JSONDump.load('after.json')
```

The set of objects that are in `after` and `before` is given by `#diff`

```
d = diff(after)
```

From there, there are multiple cases.

One is that the diff has a few roots. What is happening in this case, is that a
few objects in the `after` dump are linked to long-live objects in the
`before` dump). Let's get those

```
roots = d.roots(with_keepalive_count: true)
```

This computes the set of roots, and computes how many objects in `d` are kept alive by them. This information is stored in each record's `keepalive_count` entry, e.g.

```
roots.each_record do |r|
  puts r['keepalive_count']
end
```

Let's now keep only the roots that keep a significant number of other objects.
Use `roots.each_record.map { |r| r['keepalive_count'] }.sort.reverse` to get an
idea of the distribution

```
roots = roots.find_all { |r| r['keepalive_count'] > 5000 }
```

And lets also mark them as being "inside the after dump", which helps visualization in Gephi

```
roots = roots.map { |r| r['in_after'] = 1; r }
```

We can now generate the subgraph and dump it to GML for display

```
after.roots_of(roots).to_gml('diff.gml')
```

In summary

```
d = diff(after)
roots = d.roots(with_keepalive_count: true)
roots = roots.map { |r| r['in_after'] = 1; r }
roots = roots.find_all { |r| r['keepalive_count'] > 5000 }
after.roots_of(roots).to_gml('diff.gml')
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/doudou/memdump.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

