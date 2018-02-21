# Copyright (C) 2012 Dominik Picheta
# MIT License - Look at license.txt for details.
# Edited by @2vg
import parseutils, strtabs

export `[]`

type
  NodeType* = enum
    NodeText, NodeField
  Node* = object
    typ*: NodeType
    text*: string
    optional*: bool
  
  Pattern* = seq[Node]

#/show/@id/?
proc parsePattern*(pattern: string): Pattern =
  result = @[]
  template addNode(result: var Pattern, theT: NodeType, theText: string,
                   isOptional: bool): typed =
    block:
      var newNode: Node
      newNode.typ = theT
      newNode.text = theText
      newNode.optional = isOptional
      result.add(newNode)
  
  var i = 0
  var text = ""
  while i < pattern.len():
    case pattern[i]
    of '@':
      # Add the stored text.
      if text != "":
        result.addNode(NodeText, text, false)
        text = ""
      # Parse named parameter.
      inc(i) # Skip @
      var nparam = ""
      i += pattern.parseUntil(nparam, {'/', '?'}, i)
      var optional = pattern[i] == '?'
      result.addNode(NodeField, nparam, optional)
      if pattern[i] == '?': inc(i) # Only skip ?. / should not be skipped.
    of '?':
      var optionalChar = text[text.len-1]
      setLen(text, text.len-1) # Truncate ``text``.
      # Add the stored text.
      if text != "":
        result.addNode(NodeText, text, false)
        text = ""
      # Add optional char.
      inc(i) # Skip ?
      result.addNode(NodeText, $optionalChar, true)
    of '\\':
      inc i # Skip \
      if pattern[i] notin {'?', '@', '\\'}:
        raise newException(ValueError, 
                "This character does not require escaping: " & pattern[i])
      text.add(pattern[i])
      inc i # Skip ``pattern[i]``
    else:
      text.add(pattern[i])
      inc(i)
  
  if text != "":
    result.addNode(NodeText, text, false)

proc findNextText(pattern: Pattern, i: int, toNode: var Node): bool =
  ## Finds the next NodeText in the pattern, starts looking from ``i``.
  result = false
  for n in i..pattern.len()-1:
    if pattern[n].typ == NodeText:
      toNode = pattern[n]
      return true

proc check(n: Node, s: string, i: int): bool =
  let cutTo = (n.text.len-1)+i
  if cutTo > s.len-1: return false
  return s.substr(i, cutTo) == n.text

proc match*(pattern: Pattern, s: string): tuple[matched: bool, params: StringTableRef] =
  var i = 0 # Location in ``s``.

  result.matched = true
  result.params = {:}.newStringTable()
  
  for ncount, node in pattern:
    case node.typ
    of NodeText:
      if node.optional:
        if check(node, s, i):
          inc(i, node.text.len) # Skip over this optional character.
        else:
          # If it's not there, we have nothing to do. It's optional after all.
          discard
      else:
        if check(node, s, i):
          inc(i, node.text.len) # Skip over this
        else:
          # No match.
          result.matched = false
          return
    of NodeField:
      var nextTxtNode: Node
      var stopChar = '/'
      if findNextText(pattern, ncount, nextTxtNode):
        stopChar = nextTxtNode.text[0]
      var matchNamed = ""
      i += s.parseUntil(matchNamed, stopChar, i)
      if matchNamed != "":
        result.params[node.text] = matchNamed
      elif matchNamed == "" and not node.optional:
        result.matched = false
        return

  if s.len != i:
    result.matched = false

when isMainModule:
  let f = parsePattern("/user/@me/follow/@id/?")
  echo match(f, "/user/mfqn/follow/java_shit/")