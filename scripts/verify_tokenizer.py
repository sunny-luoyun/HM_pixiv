import json, struct, os
import regex as re

# Load binary and simulate the TS tokenizer
with open('/Users/langqin/huaweiapp/HM_pixiv/entry/src/main/resources/rawfile/deepseek_tokenizer.bin', 'rb') as f:
    data = f.read()

view = data
offset = 0

magic = view[offset:offset+4].decode(); offset += 4
version = struct.unpack('<I', view[offset:offset+4])[0]; offset += 4
vocab_size = struct.unpack('<I', view[offset:offset+4])[0]; offset += 4
merges_size = struct.unpack('<I', view[offset:offset+4])[0]; offset += 4
offset += 4

vocab_data_len = struct.unpack('<I', view[offset:offset+4])[0]; offset += 4
offset += vocab_data_len

# Build merge lookup
merge_lookup = {}
for i in range(merges_size):
    id1, id2, merged_id = struct.unpack('<III', view[offset:offset+12]); offset += 12
    merge_lookup[(id1, id2)] = (i, merged_id)

# Byte token IDs
byte_token_ids = list(struct.unpack(f'<{256}I', view[offset:offset+1024])); offset += 1024

# Byte-to-char code points
byte_to_char = list(struct.unpack(f'<{256}H', view[offset:offset+512])); offset += 512

def split_by_pattern(text, pattern):
    result = []
    regex = re.compile(pattern, re.UNICODE)
    last_idx = 0
    for m in regex.finditer(text):
        idx = m.start()
        if idx > last_idx:
            result.append(text[last_idx:idx])
        result.append(m.group())
        last_idx = idx + len(m.group())
    if last_idx < len(text):
        result.append(text[last_idx:])
    return result

def pre_tokenize(text):
    parts = [text]

    split_result = []
    for p in parts:
        s = split_by_pattern(p, r'\p{N}{1,3}')
        split_result.extend(s)
    parts = split_result

    split_result = []
    for p in parts:
        s = split_by_pattern(p, r'[\u4e00-\u9fa5\u3040-\u309f\u30a0-\u30ff]+')
        split_result.extend(s)
    parts = split_result

    complex_re = r"""[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~][A-Za-z]+|[^\r\n\p{L}\p{P}\p{S}]?[\p{L}\p{M}]+| ?[\p{P}\p{S}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"""
    split_result = []
    for p in parts:
        s = split_by_pattern(p, complex_re)
        split_result.extend(s)
    parts = split_result

    return [p for p in parts if len(p) > 0]

def bpe_merge(token_ids):
    ids = list(token_ids)
    while len(ids) > 1:
        best_rank = float('inf')
        best_idx = -1
        best_merged = 0

        for i in range(len(ids) - 1):
            entry = merge_lookup.get((ids[i], ids[i+1]))
            if entry and entry[0] < best_rank:
                best_rank = entry[0]
                best_idx = i
                best_merged = entry[1]

        if best_idx == -1:
            break

        ids[best_idx] = best_merged
        ids.pop(best_idx + 1)

    return ids

def encode(text):
    words = pre_tokenize(text)
    result = []
    for word in words:
        utf8_bytes = word.encode('utf-8')
        token_ids = [byte_token_ids[b] for b in utf8_bytes]
        merged = bpe_merge(token_ids)
        result.extend(merged)
    return result

# Compare with original tokenizer
os.chdir('/Users/langqin/Downloads/deepseek_v3_tokenizer')
from tokenizers import Tokenizer
orig = Tokenizer.from_file('tokenizer.json')

samples = [
    'Hello, world!',
    'こんにちは世界！',
    '[chapter:第1話]\nこんにちは。[[rb:漢字>かんじ]]\n[newpage]',
    'テスト文章です。DeepSeek V3のトークナイザーを試しています。',
    '私はその日、いつも通り目を覚ました。窓の外には青い空が広がっていた。',
    'Hello! こんにちは世界！123 test [[rb:日本>にほん]]\n[chapter:第1話]今日はいい天気ですね。[newpage]明日も晴れるといいな。',
]

print('=== Tokenizer Validation ===')
all_ok = True
for sample in samples:
    our_ids = encode(sample)
    orig_ids = orig.encode(sample).ids
    match = our_ids == orig_ids
    if not match:
        print(f'  FAIL: {sample[:50]}...')
        print(f'    Ours:   {our_ids}')
        print(f'    Origin: {orig_ids}')
        all_ok = False
    else:
        print(f'  OK: {sample[:50]}... ({len(orig_ids)} tokens)')

print(f'\nOverall: {"ALL PASS" if all_ok else "SOME FAILED"}')
