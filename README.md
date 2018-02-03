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
ObjectSpace.trace_object_allocations_start
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

If you mean to use dump diffs you **MUST** enable allocation tracing. Not doing
so will make the diffs inaccurate, as memdump will not be able to recognize that some
object addresses have been reused after a garbage collection.

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

We'll also add a special marker to the records in `d` so that we can easily colorize
them differently in Gephi.

```
d = d.map { |r| r['in_after'] = 1; r }
```

## Case 1: few new objects are linked to the old ones

One possibility is that there are only a few objects in the diff that are kept
alive from `before`. These objects in turn keep alive a lot more objects (which
cause the noticeable memory leak). What's interesting in this case is to
visualize the interface, that is that set of objects.

In memdump, one computes it with the `interface_with` method, which computes the
interface between the receiver and the argument. The receiver must contain the
edges between itself and the argument, which means in our case that we must use
`after`.

```
self_border, diff_border = after.interface_with(d)
```

In addition to computing the border, it computes the count of objects that are
kept alive by each object in `diff_border`. Each record in `diff_border` has an
attribute called `keepalive_count` that counts the amount of nodes in `after`
that are reachable (i.e. kept alive by) it. It is usually a good idea to
visualize the distribution of `keepalive_count` to see whether there's indeed
only a few nodes, and whether some are keeping a lot more objects alive than
others. Note that cycles that involve more than one "border node" will be
counted multiple ones (so the sum of `keepalive_count` will be higher than
`d.size`)

```
diff_border.size # is this much smaller than d.size ?
diff_border.each_record.map { |r| r['keepalive_count'] }.sort.reverse # are there some high counts at the top ?
```

From there, one needs to do a bunch of back-and-forth between memdump and Gephi.
What I usually do is start by dumping the whole subgraph that contains the border
and visualize. If I can't make any sense of it, I isolate the high-count elements
in the border and visualize the related subgraph

```
full_subgraph = after.roots_of(diff_border)
full_subgraph.to_gml 'full.gml'
filtered_border = diff_border.find_all { |r| r['keepalive_count'] > 1000 }
filtered_subgraph = after.roots_of(filtered_border)
filtered_subgraph.to_gml 'filtered.gml'
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/doudou/memdump.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

