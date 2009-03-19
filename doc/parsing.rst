.. _parsing:

====================================
Geocoder.us Address Parsing Strategy
====================================

:Author: Schuyler Erle
:Contact: schuyler at geocoder dot us
:Created: 2009/03/18
:Edited: 2009/03/18

Structured address components
-----------------------------

Unless otherwise labeled as "required", all components of a structured address
are optional.

prenum
    The alphanumeric prefix portion of a house or building number. (e.g. "32-"
    in "32-20 Jackson St".

number
    The house or building number component. Required.

sufnum
    The alphanumeric suffix portion of a house or building number. (e.g. "23B
    Baker St")

fraction
    The fractional portion of a house or building number. (e.g. "23 1/2 Baker
    St")

predir
    The prefixed street directional component. (e.g. "N", "SW")

prequal
    The prefixed street qualifier component. (e.g. "Old", "Business")

pretyp
    The prefixed street type component. (e.g. "US Hwy")

street
    The main portion of the street name. Required.

suftyp
    The suffixed street type component. (e.g. "Rd", "Ave")

sufqual
    The suffixed street qualifier component.

sufdir
    The suffixed street directional component.

unittyp
    The unit type, if any. (e.g. "Fl", "Apt", "Ste")

unit
    The unit identifer, if any.

city
    The name of the city or locale.

state
    The two letter postal state code.

zip
    The zero padded, five digit ZIP postal code.

plus4
    The zero padded, four digit ZIP+4 postal extension.

Parsing Strategy
----------------

Each component will have a regular expression, and a maximum
count. Components are ordered from first to last.

Those components drawn from finite lists - directionals, qualifiers,
types, and states - will have regular expressions composed of the union of
the corresponding list.

A *parse* will consist of a component state, a penalty count, a list of
component strings and a counter for each component.

1. Initialize an input stack, consisting of a single blank parse.

#. Split the address string on whitespace into tokens.

#. For each token:

   A. For each component:

      i. Test the token against the regular expression.
      #. If the regexp matches, add the component name to a list of matching
         components.

   #. Initialize an empty output stack.

   #. For each parse in the input stack:

      i. Copy the current parse, increment the penalty count on the new parse,
         and add it to the output stack.
      #. For each matching component for the current token:

         a. If the component state for this parse is later than the
            matching component, continue to the next matching component.
         #. If the component count for this parse state is equal to the 
            maximum count for the component, continue to the next matching
            component.
         #. Otherwise, copy the parse state, and append the token to the
            component string, with a leading space, if necessary.
         #. Increment the matching component counter for the current parse.
         #. Set the component state of the current parse to the matching
            component.
         #. Push the new parse on to the output stack.

   #. Replace the input stack with the output stack.

#. Post-process number prefix/suffixes and ZIP+4 extensions.

#. Score each parse by the number of components with non-empty strings,
   minus the penalty count of the parse.

#. Return the sorted list of parsed string lists.

