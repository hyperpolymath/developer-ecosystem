// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// ETF (Erlang Term Format) encoder/decoder

open Types

// ETF version tag
let versionTag = 131

// Term tags
let smallIntegerExt = 97
let integerExt = 98
let atomExt = 100
let smallTupleExt = 104
let largeTupleExt = 105
let nilExt = 106
let stringExt = 107
let listExt = 108
let binaryExt = 109
let smallAtomUtf8Ext = 119
let atomUtf8Ext = 118
let mapExt = 116
let newFloatExt = 70

// Helper to create Uint8Array
let uint8Array = (arr: array<int>): Js.TypedArray2.Uint8Array.t => {
  %raw(`new Uint8Array(arr)`)
}

// Helper to concatenate Uint8Arrays
let concat = (chunks: array<Js.TypedArray2.Uint8Array.t>): Js.TypedArray2.Uint8Array.t => {
  %raw(`
    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of chunks) {
      result.set(chunk, offset);
      offset += chunk.length;
    }
    return result;
  `)
}

let rec encodeTerm = (term: erlangTerm): Js.TypedArray2.Uint8Array.t => {
  switch term {
  | Nil => uint8Array([nilExt])
  | Integer(n) if n >= 0 && n <= 255 => uint8Array([smallIntegerExt, n])
  | Integer(n) =>
    %raw(`
      const buf = new ArrayBuffer(5);
      const view = new DataView(buf);
      view.setUint8(0, 98); // integerExt
      view.setInt32(1, n, false);
      new Uint8Array(buf)
    `)
  | Float(n) =>
    %raw(`
      const buf = new ArrayBuffer(9);
      const view = new DataView(buf);
      view.setUint8(0, 70); // newFloatExt
      view.setFloat64(1, n, false);
      new Uint8Array(buf)
    `)
  | Atom(name) => encodeAtom(name)
  | Binary(data) =>
    %raw(`
      const buf = new ArrayBuffer(5);
      const view = new DataView(buf);
      view.setUint8(0, 109); // binaryExt
      view.setUint32(1, data.length, false);
      const header = new Uint8Array(buf);
      const result = new Uint8Array(5 + data.length);
      result.set(header, 0);
      result.set(data, 5);
      result
    `)
  | Tuple(elements) =>
    let encodedElements = Array.map(elements, encodeTerm)
    let header = if Array.length(elements) <= 255 {
      uint8Array([smallTupleExt, Array.length(elements)])
    } else {
      %raw(`
        const buf = new ArrayBuffer(5);
        const view = new DataView(buf);
        view.setUint8(0, 105); // largeTupleExt
        view.setUint32(1, elements.length, false);
        new Uint8Array(buf)
      `)
    }
    concat(Array.concat([header], encodedElements))
  | List([]) => uint8Array([nilExt])
  | List(elements) =>
    let encodedElements = Array.map(elements, encodeTerm)
    let header = %raw(`
      const buf = new ArrayBuffer(5);
      const view = new DataView(buf);
      view.setUint8(0, 108); // listExt
      view.setUint32(1, elements.length, false);
      new Uint8Array(buf)
    `)
    let tail = uint8Array([nilExt])
    concat(Array.concatMany([[header], encodedElements, [tail]]))
  | Map(dict) =>
    let entries = Dict.toArray(dict)
    let header = %raw(`
      const buf = new ArrayBuffer(5);
      const view = new DataView(buf);
      view.setUint8(0, 116); // mapExt
      view.setUint32(1, entries.length, false);
      new Uint8Array(buf)
    `)
    let encodedPairs = Array.flatMap(entries, ((key, value)) => {
      [encodeAtom(key), encodeTerm(value)]
    })
    concat(Array.concat([header], encodedPairs))
  }
}

and encodeAtom = (name: string): Js.TypedArray2.Uint8Array.t => {
  %raw(`
    const bytes = new TextEncoder().encode(name);
    if (bytes.length <= 255) {
      const result = new Uint8Array(2 + bytes.length);
      result[0] = 119; // smallAtomUtf8Ext
      result[1] = bytes.length;
      result.set(bytes, 2);
      return result;
    } else {
      const result = new Uint8Array(3 + bytes.length);
      result[0] = 118; // atomUtf8Ext
      result[1] = (bytes.length >> 8) & 0xff;
      result[2] = bytes.length & 0xff;
      result.set(bytes, 3);
      return result;
    }
  `)
}

let encode = (term: erlangTerm): Js.TypedArray2.Uint8Array.t => {
  let header = uint8Array([versionTag])
  let body = encodeTerm(term)
  concat([header, body])
}

let decode = (data: Js.TypedArray2.Uint8Array.t): result<erlangTerm, string> => {
  %raw(`
    try {
      if (data[0] !== 131) {
        return { TAG: 1, _0: "Invalid ETF version tag: " + data[0] };
      }
      const [term, _] = decodeTerm(data, 1);
      return { TAG: 0, _0: term };
    } catch (e) {
      return { TAG: 1, _0: e.message };
    }

    function decodeTerm(data, offset) {
      const tag = data[offset];
      offset++;

      switch (tag) {
        case 97: // SMALL_INTEGER
          return [{ TAG: 0, _0: data[offset] }, offset + 1]; // Integer

        case 98: { // INTEGER
          const view = new DataView(data.buffer, data.byteOffset + offset, 4);
          return [{ TAG: 0, _0: view.getInt32(0, false) }, offset + 4]; // Integer
        }

        case 70: { // NEW_FLOAT
          const view = new DataView(data.buffer, data.byteOffset + offset, 8);
          return [{ TAG: 1, _0: view.getFloat64(0, false) }, offset + 8]; // Float
        }

        case 100:
        case 118: { // ATOM_UTF8
          const len = new DataView(data.buffer, data.byteOffset + offset, 2).getUint16(0, false);
          const name = new TextDecoder().decode(data.slice(offset + 2, offset + 2 + len));
          return [{ TAG: 2, _0: name }, offset + 2 + len]; // Atom
        }

        case 119: { // SMALL_ATOM_UTF8
          const len = data[offset];
          const name = new TextDecoder().decode(data.slice(offset + 1, offset + 1 + len));
          return [{ TAG: 2, _0: name }, offset + 1 + len]; // Atom
        }

        case 106: // NIL
          return [{ TAG: 7 }, offset]; // Nil

        case 108: { // LIST
          const len = new DataView(data.buffer, data.byteOffset + offset, 4).getUint32(0, false);
          offset += 4;
          const items = [];
          for (let i = 0; i < len; i++) {
            const [item, newOffset] = decodeTerm(data, offset);
            items.push(item);
            offset = newOffset;
          }
          const [_, tailOffset] = decodeTerm(data, offset);
          return [{ TAG: 5, _0: items }, tailOffset]; // List
        }

        case 104: { // SMALL_TUPLE
          const len = data[offset];
          offset++;
          const items = [];
          for (let i = 0; i < len; i++) {
            const [item, newOffset] = decodeTerm(data, offset);
            items.push(item);
            offset = newOffset;
          }
          return [{ TAG: 4, _0: items }, offset]; // Tuple
        }

        case 105: { // LARGE_TUPLE
          const len = new DataView(data.buffer, data.byteOffset + offset, 4).getUint32(0, false);
          offset += 4;
          const items = [];
          for (let i = 0; i < len; i++) {
            const [item, newOffset] = decodeTerm(data, offset);
            items.push(item);
            offset = newOffset;
          }
          return [{ TAG: 4, _0: items }, offset]; // Tuple
        }

        case 109: { // BINARY
          const len = new DataView(data.buffer, data.byteOffset + offset, 4).getUint32(0, false);
          return [{ TAG: 3, _0: data.slice(offset + 4, offset + 4 + len) }, offset + 4 + len]; // Binary
        }

        case 116: { // MAP
          const len = new DataView(data.buffer, data.byteOffset + offset, 4).getUint32(0, false);
          offset += 4;
          const map = {};
          for (let i = 0; i < len; i++) {
            const [key, keyOffset] = decodeTerm(data, offset);
            const [value, valueOffset] = decodeTerm(data, keyOffset);
            if (key.TAG === 2) { // Atom
              map[key._0] = value;
            }
            offset = valueOffset;
          }
          return [{ TAG: 6, _0: map }, offset]; // Map
        }

        default:
          throw new Error("Unknown ETF tag: " + tag);
      }
    }
  `)
}
