title: Perl Markdown Upgrade Test
date: 2026-06-04

## 1. Inline Formatting Tests

We need to ensure that the inline processor handles both strict and loose formatting accurately. 
* This is *italic text* using asterisks.
* This is _italic text_ using underscores.
* This is **bold text** using double asterisks.
* This is __bold text__ using double underscores.

Let's test a [Hyperlink to the CommonMark Spec](https://commonmark.org/) to verify our new inline link parser is capturing the URL without greedy backtracking.

***

## 2. Block-Level Tests

The thematic break above used three asterisks. Below, we will test blockquotes and lists.

> "Code is read much more often than it is written." 
> This is a multiline blockquote to test if the parser maintains state correctly.

### Unordered List Parsing

The following list uses hyphens:
- First item in the list
- Second item, which contains **bold text**
- Third item with a [link](https://perl.org)

The following list uses asterisks:
* Alpha
* Beta
* Gamma

---

## 3. Edge Cases & Terminations

The thematic break above used three hyphens. 

If the state machine is working flawlessly, the lists and blockquotes should have been closed exactly when a blank line or a new structural element (like a header or horizontal rule) was encountered, preventing nested tag bleeding in the HTML output.
