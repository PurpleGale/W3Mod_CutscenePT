"""
W3Strings Next-Gen Encoder & Decoder (Version 164)
Compatible with The Witcher 3: Wild Hunt v4.04+ / REDkit v5.00c+
"""

import os
import struct
import io
import argparse

LANGUAGES = {
    'ar':   {'key1': 0x0000, 'key2': 0x0000, 'magic': 0x00000000},
    'br':   {'key1': 0x0000, 'key2': 0x0000, 'magic': 0x00000000},
    'esmx': {'key1': 0x0000, 'key2': 0x0000, 'magic': 0x00000000},
    'kr':   {'key1': 0x0000, 'key2': 0x0000, 'magic': 0x00000000},
    'tr':   {'key1': 0x0000, 'key2': 0x0000, 'magic': 0x00000000},
    'pl':   {'key1': 0x8349, 'key2': 0x6237, 'magic': 0x73946816},
    'en':   {'key1': 0x4397, 'key2': 0x5139, 'magic': 0x79321793},
    'de':   {'key1': 0x7588, 'key2': 0x6138, 'magic': 0x42791159},
    'it':   {'key1': 0x4593, 'key2': 0x1894, 'magic': 0x12375973},
    'fr':   {'key1': 0x2386, 'key2': 0x3176, 'magic': 0x75921975},
    'cz':   {'key1': 0x2498, 'key2': 0x7354, 'magic': 0x21793217},
    'es':   {'key1': 0x1879, 'key2': 0x6651, 'magic': 0x42387566},
    'zh':   {'key1': 0x1863, 'key2': 0x2176, 'magic': 0x16875467},
    'cn':   {'key1': 0x1863, 'key2': 0x2176, 'magic': 0x16875467},
    'ru':   {'key1': 0x6348, 'key2': 0x1486, 'magic': 0x42386347},
    'hu':   {'key1': 0x4237, 'key2': 0x8932, 'magic': 0x67823218},
    'jp':   {'key1': 0x5483, 'key2': 0x4893, 'magic': 0x59825646},
    'ua':   {'key1': 0x0000, 'key2': 0x0000, 'magic': 0x00000000},
    'cleartext': {'key1': 0x0000, 'key2': 0x0000, 'magic': 0x00000000},
}

def hash_key(key: str) -> int:
    h = 0
    for c in key.lower():
        h = ((h * 31) + ord(c)) & 0xffffffff
    return h

def read_bit6(f) -> int:
    result = 0
    shift = 0
    i = 1
    while True:
        data = f.read(1)
        if not data:
            raise EOFError("Unexpected end of file while reading bit6")
        b = data[0]
        s = 6
        mask = 255
        if b > 127:
            mask = 127
            s = 7
        elif b > 63:
            if i == 1:
                mask = 63
        if shift < 32:
            result |= (b & mask) << shift
        shift += s
        if b < 64 or (i >= 3 and b < 128):
            break
        i += 1
    return result

def encode_bit6(val: int) -> bytes:
    if val < 64:
        return bytes([val])
    res = bytearray()
    res.append((val & 0x3f) | 0x40)
    val >>= 6
    while val >= 128:
        res.append((val & 0x7f) | 0x80)
        val >>= 7
    res.append(val & 0x7f)
    return bytes(res)

def decode_w3strings(filepath: str) -> tuple[str, list[dict]]:
    with open(filepath, 'rb') as f:
        magic = f.read(4)
        if magic != b'RTSW':
            raise ValueError(f"Invalid magic: {magic}")
        version, = struct.unpack('<I', f.read(4))
        key1, = struct.unpack('<H', f.read(2))
        f.seek(-2, 2)
        key2, = struct.unpack('<H', f.read(2))
        full_key = (key1 << 16) | key2
        
        # Match language
        lang_code = None
        lang_info = None
        for code, info in LANGUAGES.items():
            if info['key1'] == key1 and info['key2'] == key2:
                lang_code = code
                lang_info = info
                break
        
        if not lang_info:
            raise ValueError(f"Unknown language key: {hex(key1)}:{hex(key2)}")
        
        magic_val = lang_info['magic']
        
        f.seek(10)
        b1_count = read_bit6(f)
        b1 = []
        for _ in range(b1_count):
            sid_h, = struct.unpack('<I', f.read(4))
            off, = struct.unpack('<I', f.read(4))
            slen, = struct.unpack('<I', f.read(4))
            b1.append({'id': sid_h ^ magic_val, 'offset': off, 'strlen': slen, 'sid_h': sid_h})
        
        b2_count = read_bit6(f)
        b2 = {}
        for _ in range(b2_count):
            k_hex, = struct.unpack('<I', f.read(4))
            sid_h, = struct.unpack('<I', f.read(4))
            b2[sid_h ^ magic_val] = k_hex
            
        b3_count = read_bit6(f)
        str_start = f.tell()
        
        # Read and decrypt strings
        sk_init = (magic_val >> 8) & 0xffff
        entries = []
        for item in b1:
            sid = item['id']
            off = item['offset']
            slen = item['strlen']
            
            f.seek(str_start + off)
            raw = f.read(slen)
            
            if version >= 164:
                # 1-byte UTF-8 encryption
                dec = bytearray(raw)
                if magic_val != 0:
                    sk = sk_init
                    for idx in range(slen):
                        char_key = ((slen + 1) * sk) & 0xff
                        dec[idx] ^= char_key
                        sk = ((sk << 1) | (sk >> 15)) & 0xffff
                text = dec.decode('utf-8', errors='replace')
            else:
                # 2-byte UTF-16 encryption
                chars = []
                sk = sk_init
                for idx in range(0, slen * 2, 2):
                    b1_b = raw[idx]
                    b2_b = raw[idx+1]
                    if magic_val != 0:
                        char_key = ((slen + 1) * sk) & 0xffff
                        b1_b ^= (char_key & 0xff)
                        b2_b ^= ((char_key >> 8) & 0xff)
                        sk = ((sk << 1) | (sk >> 15)) & 0xffff
                    chars.append(chr(b1_b | (b2_b << 8)))
                text = "".join(chars)
                
            k_hex_str = f"{b2[sid]:08x}" if sid in b2 else ""
            entries.append({'id': sid, 'key_hex': k_hex_str, 'key_str': '', 'text': text})
            
        return lang_code, entries

def encode_w3strings(entries: list[dict], lang_code: str, output_path: str, version: int = 164):
    lang_info = LANGUAGES.get(lang_code.lower())
    if not lang_info:
        raise ValueError(f"Unsupported language code: {lang_code}")
        
    magic_val = lang_info['magic']
    key1 = lang_info['key1']
    key2 = lang_info['key2']
    
    # Process string entries and build raw string buffer
    # Sort block1 entries by (str_id ^ magic_val)
    sorted_entries = sorted(entries, key=lambda e: e['id'] ^ magic_val)
    
    string_buffer = bytearray()
    sk_init = (magic_val >> 8) & 0xffff
    
    block1_data = []
    for entry in sorted_entries:
        text = entry['text']
        raw_utf8 = text.encode('utf-8')
        slen = len(raw_utf8)
        off = len(string_buffer)
        
        # Encrypt 1-byte at a time
        enc = bytearray(raw_utf8)
        if magic_val != 0:
            sk = sk_init
            for idx in range(slen):
                char_key = ((slen + 1) * sk) & 0xff
                enc[idx] ^= char_key
                sk = ((sk << 1) | (sk >> 15)) & 0xffff
                
        string_buffer.extend(enc)
        string_buffer.append(0)  # null terminator
        
        block1_data.append({
            'str_id_hashed': entry['id'] ^ magic_val,
            'offset': off,
            'strlen': slen,
        })
        
    # Block 2: key hash mappings sorted by str_key_hex
    block2_entries = []
    for entry in entries:
        k_hex = None
        if entry.get('key_hex'):
            try:
                k_hex = int(entry['key_hex'], 16)
            except ValueError:
                pass
        if k_hex is None and entry.get('key_str'):
            k_hex = hash_key(entry['key_str'])
            
        if k_hex is not None:
            block2_entries.append({
                'key_hex': k_hex,
                'str_id_hashed': entry['id'] ^ magic_val
            })
            
    block2_entries.sort(key=lambda item: item['key_hex'])
    
    # Write output binary file
    with open(output_path, 'wb') as f:
        # 1. Magic
        f.write(b'RTSW')
        # 2. Version (164)
        f.write(struct.pack('<I', version))
        # 3. Key1
        f.write(struct.pack('<H', key1))
        
        # 4. Block 1
        f.write(encode_bit6(len(block1_data)))
        for item in block1_data:
            f.write(struct.pack('<I', item['str_id_hashed']))
            f.write(struct.pack('<I', item['offset']))
            f.write(struct.pack('<I', item['strlen']))
            
        # 5. Block 2
        f.write(encode_bit6(len(block2_entries)))
        for item in block2_entries:
            f.write(struct.pack('<I', item['key_hex']))
            f.write(struct.pack('<I', item['str_id_hashed']))
            
        # 6. Block 3 count (string buffer length in bytes)
        f.write(encode_bit6(len(string_buffer)))
        # 7. String buffer
        f.write(string_buffer)
        # 8. Key2
        f.write(struct.pack('<H', key2))

def parse_csv(csv_path: str) -> tuple[str, list[dict]]:
    with open(csv_path, 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()
        
    lang = 'en'
    entries = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith(';meta[language='):
            lang = line[len(';meta[language='):-1].strip()
            continue
        if line.startswith(';'):
            continue
        parts = line.split('|')
        if len(parts) >= 4:
            sid = int(parts[0].strip())
            k_hex = parts[1].strip()
            k_str = parts[2].strip()
            text = parts[3]
            entries.append({'id': sid, 'key_hex': k_hex, 'key_str': k_str, 'text': text})
    return lang, entries

def write_csv(lang: str, entries: list[dict], csv_path: str):
    with open(csv_path, 'w', encoding='utf-8') as f:
        f.write(f";meta[language={lang}]\n")
        f.write("; id      |key(hex)|key(str)| text\n")
        for e in entries:
            f.write(f"{e['id']}|{e['key_hex']}|{e['key_str']}|{e['text']}\n")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Witcher 3 Next-Gen w3strings converter")
    parser.add_argument('-e', '--encode', help="Encode CSV to w3strings")
    parser.add_argument('-d', '--decode', help="Decode w3strings to CSV")
    parser.add_argument('-o', '--output', help="Output file path")
    args = parser.parse_args()
    
    if args.encode:
        lang, entries = parse_csv(args.encode)
        out = args.output or (os.path.splitext(args.encode)[0] + '.w3strings')
        encode_w3strings(entries, lang, out)
        print(f"Encoded {len(entries)} strings to {out} (lang={lang}, v164)")
    elif args.decode:
        lang, entries = decode_w3strings(args.decode)
        out = args.output or (args.decode + '.csv')
        write_csv(lang, entries, out)
        print(f"Decoded {len(entries)} strings to {out} (lang={lang})")
