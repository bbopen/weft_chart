//// SVG element construction helpers.
////
//// Thin wrappers around `lustre/element.namespaced` for building SVG
//// trees without repeating namespace URIs.

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}

/// The SVG namespace URI.
pub const svg_ns = "http://www.w3.org/2000/svg"

/// The XHTML namespace URI (for foreignObject content).
pub const xhtml_ns = "http://www.w3.org/1999/xhtml"

/// Create an SVG-namespaced element.
pub fn el(
  tag tag: String,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  element.namespaced(svg_ns, tag, attrs, children)
}

/// Create an XHTML-namespaced element (for use inside foreignObject).
pub fn xhtml(
  tag tag: String,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  element.namespaced(xhtml_ns, tag, attrs, children)
}

/// Set an SVG attribute (untyped string key-value).
pub fn attr(name: String, value: String) -> Attribute(msg) {
  attribute.attribute(name, value)
}

/// Shorthand for creating a `<g>` group element.
pub fn g(
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(tag: "g", attrs: attrs, children: children)
}

/// Shorthand for creating a `<path>` element.
pub fn path(d d: String, attrs attrs: List(Attribute(msg))) -> Element(msg) {
  el(tag: "path", attrs: [attr("d", d), ..attrs], children: [])
}

/// Shorthand for creating a `<line>` element.
pub fn line(
  x1 x1: String,
  y1 y1: String,
  x2 x2: String,
  y2 y2: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  el(
    tag: "line",
    attrs: [
      attr("x1", x1),
      attr("y1", y1),
      attr("x2", x2),
      attr("y2", y2),
      ..attrs
    ],
    children: [],
  )
}

/// Shorthand for creating a `<rect>` element.
pub fn rect(
  x x: String,
  y y: String,
  width width: String,
  height height: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  el(
    tag: "rect",
    attrs: [
      attr("x", x),
      attr("y", y),
      attr("width", width),
      attr("height", height),
      ..attrs
    ],
    children: [],
  )
}

/// Shorthand for creating a `<circle>` element.
pub fn circle(
  cx cx: String,
  cy cy: String,
  r r: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  el(
    tag: "circle",
    attrs: [attr("cx", cx), attr("cy", cy), attr("r", r), ..attrs],
    children: [],
  )
}

/// Shorthand for creating a `<text>` element.
pub fn text(
  x x: String,
  y y: String,
  content content: String,
  attrs attrs: List(Attribute(msg)),
) -> Element(msg) {
  el(tag: "text", attrs: [attr("x", x), attr("y", y), ..attrs], children: [
    element.text(content),
  ])
}

/// Create a `<defs>` element containing gradient/filter definitions.
pub fn defs(children: List(Element(msg))) -> Element(msg) {
  el(tag: "defs", attrs: [], children: children)
}

/// Create a vertical `<linearGradient>` element.
pub fn linear_gradient(
  id id: String,
  stops stops: List(Element(msg)),
) -> Element(msg) {
  el(
    tag: "linearGradient",
    attrs: [
      attr("id", id),
      attr("x1", "0"),
      attr("y1", "0"),
      attr("x2", "0"),
      attr("y2", "1"),
    ],
    children: stops,
  )
}

/// Create a gradient `<stop>` element.
pub fn gradient_stop(
  offset offset: String,
  color color: String,
  opacity opacity: String,
) -> Element(msg) {
  el(
    tag: "stop",
    attrs: [
      attr("offset", offset),
      attr("stop-color", color),
      attr("stop-opacity", opacity),
    ],
    children: [],
  )
}

/// Create a `<clipPath>` element with an id.
pub fn clip_path(
  id id: String,
  children children: List(Element(msg)),
) -> Element(msg) {
  el(tag: "clipPath", attrs: [attr("id", id)], children: children)
}

/// Path element with children (for embedding `<animate>` elements).
pub fn path_with_children(
  d d: String,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(tag: "path", attrs: [attr("d", d), ..attrs], children: children)
}

/// Rectangle element with children (for embedding `<animate>` elements).
pub fn rect_with_children(
  x x: String,
  y y: String,
  width width: String,
  height height: String,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(
    tag: "rect",
    attrs: [
      attr("x", x),
      attr("y", y),
      attr("width", width),
      attr("height", height),
      ..attrs
    ],
    children: children,
  )
}

/// Circle element with children (for embedding `<animate>` elements).
pub fn circle_with_children(
  cx cx: String,
  cy cy: String,
  r r: String,
  attrs attrs: List(Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  el(
    tag: "circle",
    attrs: [attr("cx", cx), attr("cy", cy), attr("r", r), ..attrs],
    children: children,
  )
}
