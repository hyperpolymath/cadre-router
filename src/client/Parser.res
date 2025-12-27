// SPDX-License-Identifier: Apache-2.0
// Parser.res — Elm-style URL parser combinators

type state = {
  remaining: list<string>,
  url: Url.t,
}

type t<'a> = state => option<('a, state)>

// === Path Segment Matchers ===

let s = (literal: string): t<unit> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} if head == literal =>
      Some(((), {...state, remaining: tail}))
    | _ => None
    }
  }
}

let str: t<string> = state => {
  switch state.remaining {
  | list{head, ...tail} if head != "" =>
    Some((head, {...state, remaining: tail}))
  | _ => None
  }
}

let int: t<int> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    switch Belt.Int.fromString(head) {
    | Some(n) => Some((n, {...state, remaining: tail}))
    | None => None
    }
  | list{} => None
  }
}

let custom = (parse: string => option<'a>): t<'a> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} =>
      switch parse(head) {
      | Some(value) => Some((value, {...state, remaining: tail}))
      | None => None
      }
    | list{} => None
    }
  }
}

let top: t<unit> = state => {
  switch state.remaining {
  | list{} => Some(((), state))
  | _ => None
  }
}

// === Combinators ===

let andThen = (parserA: t<'a>, parserB: t<'b>): t<('a, 'b)> => {
  state => {
    switch parserA(state) {
    | Some((a, stateAfterA)) =>
      switch parserB(stateAfterA) {
      | Some((b, stateAfterB)) => Some(((a, b), stateAfterB))
      | None => None
      }
    | None => None
    }
  }
}

let \"</>" = andThen

let map = (parser: t<'a>, fn: 'a => 'b): t<'b> => {
  state => {
    switch parser(state) {
    | Some((a, newState)) => Some((fn(a), newState))
    | None => None
    }
  }
}

let \"<$>" = (fn: 'a => 'b, parser: t<'a>): t<'b> => map(parser, fn)

let oneOf = (parsers: array<t<'a>>): t<'a> => {
  state => {
    let result = ref(None)
    let i = ref(0)
    let len = Belt.Array.length(parsers)

    while result.contents == None && i.contents < len {
      switch parsers[i.contents] {
      | Some(parser) =>
        switch parser(state) {
        | Some(_) as success => result := success
        | None => i := i.contents + 1
        }
      | None => i := i.contents + 1
      }
    }

    result.contents
  }
}

let optional = (parser: t<'a>): t<option<'a>> => {
  state => {
    switch parser(state) {
    | Some((a, newState)) => Some((Some(a), newState))
    | None => Some((None, state))
    }
  }
}

// === Query Parameters ===

let query = (key: string): t<option<string>> => {
  state => {
    let value = state.url->Url.getQueryParam(key)
    Some((value, state))
  }
}

let queryInt = (key: string): t<option<int>> => {
  state => {
    let value = state.url->Url.getQueryParamInt(key)
    Some((value, state))
  }
}

let queryBool = (key: string): t<option<bool>> => {
  state => {
    let value = state.url->Url.getQueryParamBool(key)
    Some((value, state))
  }
}

let queryRequired = (key: string): t<string> => {
  state => {
    switch state.url->Url.getQueryParam(key) {
    | Some(value) => Some((value, state))
    | None => None
    }
  }
}

// === Execution ===

let parse = (parser: t<'a>, url: Url.t): option<'a> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, finalState)) =>
    // Only succeed if all path segments were consumed
    switch finalState.remaining {
    | list{} => Some(result)
    | _ => None
    }
  | None => None
  }
}

let parsePartial = (parser: t<'a>, url: Url.t): option<'a> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, _)) => Some(result)
  | None => None
  }
}
