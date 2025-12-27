// SPDX-License-Identifier: Apache-2.0
// Parser.resi — Elm-style URL parser combinators

/**
 * Parser state: remaining path segments and the URL for query access
 */
type state = {
  remaining: list<string>,
  url: Url.t,
}

/**
 * A parser that consumes path segments and produces a value of type 'a.
 * Returns None if parsing fails.
 */
type t<'a> = state => option<('a, state)>

// === Path Segment Matchers ===

/** Match a literal path segment. Fails if segment doesn't match. */
let s: string => t<unit>

/** Capture any non-empty string segment */
let str: t<string>

/** Capture an integer segment. Fails if not a valid integer. */
let int: t<int>

/** Custom segment parser. Use for typed IDs like JourneyId.t */
let custom: (string => option<'a>) => t<'a>

/** Match end of path (no more segments). Use to ensure exact match. */
let top: t<unit>

// === Combinators ===

/** Sequential composition: match A then B */
let andThen: (t<'a>, t<'b>) => t<('a, 'b)>

/** Operator form of andThen: parserA </> parserB */
let \"</>": (t<'a>, t<'b>) => t<('a, 'b)>

/** Transform parser result */
let map: (t<'a>, 'a => 'b) => t<'b>

/** Operator form: fn <$> parser (applicative-style) */
let \"<$>": ('a => 'b, t<'a>) => t<'b>

/** Try alternatives in order until one succeeds */
let oneOf: array<t<'a>> => t<'a>

/** Optional: succeed with None if parser fails */
let optional: t<'a> => t<option<'a>>

// === Query Parameters ===

/** Parse optional query parameter */
let query: string => t<option<string>>

/** Parse optional query parameter as int */
let queryInt: string => t<option<int>>

/** Parse optional query parameter as bool */
let queryBool: string => t<option<bool>>

/** Parse required query parameter (fails if missing) */
let queryRequired: string => t<string>

// === Execution ===

/** Run parser against a URL. Returns Some if successful and all path consumed. */
let parse: (t<'a>, Url.t) => option<'a>

/** Run parser, allowing unconsumed path segments */
let parsePartial: (t<'a>, Url.t) => option<'a>
