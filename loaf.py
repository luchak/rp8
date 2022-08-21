from collections import Counter
from enum import Enum
import os
import sys

sys.path.append(os.path.join(os.getcwd(), 'shrinko8'))

from pico_process import SubLanguageBase, is_ident_char, Scope, Local, Global
from utils import LazyDict

loaf_builtins = {
    '\'', 'if', 'fn', 'seq', '+', '*', '~', 'not', 'or', '@', '@=', 'for',
    'set', 'let', 'eq', 'gt', 'cat', 'len', '`'
}

class LoafNodeKind(Enum):
    # function definition
    FN = 'FN'

    # sequence of expressions
    # function body or seq keyword
    SEQ = 'SEQ'

    # quoted value
    QUOTE = 'QUOTE'

    # other expression
    EXPR = 'EXPR'

    # reference to global or local variable
    VAR = 'VAR'

    # reference to property
    PROPERTY = 'PROPERTY'

    # interpolated value in parse
    INTERP = 'INTERP'

    # ordered list in parsed data
    # NOT loaf expr!
    LIST = 'LIST'

    # key/value dictionary in parsed data
    DICT = 'DICT'
    DICT_ENTRY = 'DICT_ENTRY'

    # literals
    NUMBER = 'NUMBER'
    STRING = 'STRING'
    BOOLEAN = 'BOOLEAN'
    NIL = 'NIL'

class LoafVarAccess(Enum):
    READ = 'READ'
    WRITE = 'WRITE'

class LoafVarLocality(Enum):
    UNKNOWN = 'UNKNOWN'
    GLOBAL = 'GLOBAL'
    LOCAL = 'LOCAL'

class LoafParseError(Exception):
    pass

class LoafNode:
    def __init__(self, kind, children=None, **kwargs):
        self.kind = kind
        self.children = children
        self.__dict__.update(kwargs)

        if children is not None:
            for child in children:
                child.parent = self

        self.scope = None
        self.var_obj = None
        self.arg_objs = None

    def __repr__(self):
        contents = ''
        contents = ', '.join(
            f'{prop}={self.__dict__[prop]}'
            for prop in ('kind', 'children', 'name', 'args', 'value', 'access', 'locality', 'prefix')
            if prop in self.__dict__ and self.__dict__[prop] is not None
        )
        return f'LoafNode({contents})'

def loaf_format_string(s):
    out = ''
    for c in s:
        o = ord(c)
        if (o<35 or o==92 or o>126) and (o != 32):
            out += '\\' + chr(48+(o>>4&0x0f)) + chr(48+(o&0x0f))
        else:
            out += c
    return out

def loaf_find_vars(l):
    return [
        LoafNode(LoafNodeKind.VAR, name=val.value[1:], access=LoafVarAccess.READ, locality=LoafVarLocality.UNKNOWN, prefix='$')
        if val.kind == LoafNodeKind.STRING and len(val.value) > 0 and val.value[0] == '$'
        else val
        for val in l
    ]

def loaf_postprocess_list(l, is_code):
    if not is_code:
        return LoafNode(LoafNodeKind.LIST, children=l)

    head = l[0]

    if head.kind != LoafNodeKind.STRING:
        return LoafNode(LoafNodeKind.EXPR, children=loaf_find_vars(l))

    head = head.value

    if head == 'fn':
        if l[1].kind != LoafNodeKind.LIST:
            raise LoafParseError('Args are not a list')
        return LoafNode(
            LoafNodeKind.FN,
            children=loaf_find_vars(l[2:]),
            args=[node.value for node in l[1].children]
        )
    elif head == 'seq':
        return LoafNode(LoafNodeKind.SEQ, children=l[1:])
    elif head == '\'':
        return LoafNode(LoafNodeKind.QUOTE, children=[l[1]])
    else:
        children = [LoafNode(LoafNodeKind.VAR, name=head, access=LoafVarAccess.READ, locality=LoafVarLocality.UNKNOWN, prefix='')]
        children.extend(loaf_find_vars(l[1:]))

        if ((head == 'set') or (head == 'let')) and children[1].kind != LoafNodeKind.STRING:
            raise LoafParseError('Invalid set/let with a non-constant identifier')

        if head =='set':
            children[1] = LoafNode(LoafNodeKind.VAR, name=children[1].value, access=LoafVarAccess.WRITE,
                                   locality=LoafVarLocality.GLOBAL, prefix='')
        elif head =='let':
            children[1] = LoafNode(LoafNodeKind.VAR, name=children[1].value, access=LoafVarAccess.WRITE,
                                   locality=LoafVarLocality.LOCAL, prefix='')
        elif head =='@=' and children[2].kind == LoafNodeKind.STRING:
            children[2] = LoafNode(LoafNodeKind.PROPERTY, name=children[2].value)
        elif head =='@' and children[2].kind == LoafNodeKind.STRING:
            for i, child in enumerate(children):
                if i >= 2 and children[i].kind == LoafNodeKind.STRING:
                    children[i] = LoafNode(LoafNodeKind.PROPERTY, name=children[i].value)
        return LoafNode(LoafNodeKind.EXPR, children=children)


def loaf_parse(str, init_is_code):
    if init_is_code:
        str = '(seq ' + str + ')'

    pos = -1

    def is_num_char(ch):
        return ch and ch in '0123456789.-'

    def is_id_char(ch):
        return ch and ch not in ' \r\n\t,)}'

    def is_sep_char(ch):
        return ch and ch in ' \r\n\t,'

    def read(count=1):
        nonlocal pos
        pos += count
        return str[pos]

    def consume(test):
        substr = ''
        ch = read()
        while test(ch):
            substr = substr + ch
            if ch == '\\':
                ch = chr((ord(read()) - 48) << 4 | (ord(read()) - 48))
            ch = read()
        return substr

    def _parse(is_code):
        ch = ''

        def skip_seps():
            nonlocal ch
            ch = read()
            while is_sep_char(ch):
                ch = read()

        skip_seps()
        if ch == '"':
            return LoafNode(LoafNodeKind.STRING, value=consume(lambda x: x != '"'))
        elif is_num_char(ch):
            n = ch + consume(is_num_char)
            read(-1)
            return LoafNode(LoafNodeKind.NUMBER, value=float(n))
        elif ch == '(':
            l = []
            quoted = False
            while True:
                skip_seps()
                if ch == ')':
                    return loaf_postprocess_list(l, is_code)
                read(-1)
                l.append(_parse(is_code and not quoted))
                if len(l) == 1 and l[0].kind == LoafNodeKind.STRING:
                    if l[0].value == '\'':
                        quoted = True
                    elif l[0].value == 'fn':
                        l.append(_parse(False))
        elif ch == '{':
            kv_pairs = []
            if is_code:
                raise LoafParseError('Found dictionary in code context')
            while True:
                skip_seps()
                if ch == '}':
                        return LoafNode(
                            LoafNodeKind.DICT,
                            children=[LoafNode(LoafNodeKind.DICT_ENTRY, children=kv) for kv in kv_pairs]
                        )
                key = ch + consume(lambda x: x != '=')
                if is_num_char(key[0]):
                    key = LoafNode(LoafNodeKind.NUMBER, value=float(key))
                else:
                    key = LoafNode(LoafNodeKind.PROPERTY, name=key)
                kv_pairs.append((key, _parse(False)))
        elif ch == '`':
            if is_code:
                raise LoafParseError('Found value interpolation in code context')
            return LoafNode(LoafNodeKind.INTERP, children=[_parse(True)])
        else:
            b = ch + consume(is_id_char)

            read(-1)
            if b == 'true':
                return LoafNode(LoafNodeKind.BOOLEAN, value=True)
            if b == 'false':
                return LoafNode(LoafNodeKind.BOOLEAN, value=False)
            if b == 'nil':
                return LoafNode(LoafNodeKind.NIL)
            return LoafNode(LoafNodeKind.STRING, value=b)
    return _parse(init_is_code)

def loaf_walk(node, cb_pre=None, cb_post=None):
    if cb_pre is not None:
        cb_pre(node)
    if node.children is not None:
        for child in node.children:
            loaf_walk(child, cb_pre, cb_post)
    if cb_post is not None:
        cb_post(node)

def loaf_is_expr_with_head(node, head):
    return (
        node.kind == LoafNodeKind.EXPR and
        node.children[0].kind == LoafNodeKind.VAR and
        node.children[0].name == head
    )

def loaf_print_indent(root, stop_width=2):
    state = {'indent': 0}

    def cb_pre(node):
        contents = ', '.join(
            f'{prop}={getattr(node, prop)}'
            for prop in ('kind', 'name', 'args', 'value', 'access', 'locality', 'prefix')
            if hasattr(node, prop) and (getattr(node, prop) is not None)
        )
        print((' ' * state['indent']) + contents)
        state['indent'] += stop_width

    def cb_post(node):
        state['indent'] -= stop_width

    loaf_walk(root, cb_pre, cb_post)

def loaf_find_set_globals(root):
    globals = set()

    def cb_pre(node):
        if (
            node.kind == LoafNodeKind.VAR and
            node.access == LoafVarAccess.WRITE and
            node.locality == LoafVarLocality.GLOBAL
        ):
            globals.add(node.name)

    loaf_walk(root, cb_pre)
    return globals

def loaf_construct_scopes(root):
    def create_scope(parent=None):
        scope = Scope(parent)
        scope.used_globals = set()
        scope.used_locals = set()
        scope.loaf_declared_locals = set(parent.loaf_declared_locals) if parent is not None else set()
        scope.loaf_children = []
        if parent is not None:
            parent.loaf_children.append(scope)
        return scope

    stack = [create_scope()]
    globals = LazyDict(lambda key: Global(key))

    def cb_pre(node):
        scope = stack[-1]

        if node.kind == LoafNodeKind.FN:
            node.arg_objs = {}
            scope = create_scope(scope)
            for arg in node.args:
                local = Local(arg, scope)
                scope.add(local)
                scope.loaf_declared_locals.add(local)
                node.arg_objs[arg] = local
            stack.append(scope)
        elif node.kind == LoafNodeKind.INTERP:
            scope = create_scope()
            stack.append(scope)
        elif node.kind == LoafNodeKind.VAR:
            if node.access == LoafVarAccess.READ:
                local = scope.find(node.name)
                if local is not None:
                    node.locality = LoafVarLocality.LOCAL
                    node.var_obj = local
                    scope.used_locals.add(local)
                else:
                    node.locality = LoafVarLocality.GLOBAL
                    node.var_obj = globals[node.name]
                    scope.used_globals.add(node.name)
            elif node.access == LoafVarAccess.WRITE and node.locality == LoafVarLocality.LOCAL:
                local = None
                if node.name in scope.items:
                    local = scope.items[node.name]
                if local is None:
                    local = Local(node.name, scope)
                    scope.add(local)
                    scope.loaf_declared_locals.add(local)
                assert(local is not None)
                node.var_obj = local
            elif node.access == LoafVarAccess.WRITE and node.locality == LoafVarLocality.GLOBAL:
                node.var_obj = globals[node.name]
                scope.used_globals.add(node.name)

            assert(node.locality != LoafVarLocality.UNKNOWN)
            assert(node.var_obj is not None)

        node.scope = scope

    def cb_post(node):
        if node.kind == LoafNodeKind.FN or node.kind == LoafNodeKind.INTERP:
            scope = stack.pop()

            assert(scope == node.scope)

            for child in scope.loaf_children:
                scope.used_globals |= child.used_globals
                scope.used_locals |= child.used_locals
            scope.used_locals &= scope.loaf_declared_locals

    assert(len(stack) == 1)
    loaf_walk(root, cb_pre, cb_post)

def loaf_count_property_uses(root):
    props = Counter()

    def cb_pre(node):
        if node.kind == LoafNodeKind.PROPERTY:
            props[node.name] += 1

    loaf_walk(root, cb_pre)
    return props

def loaf_count_global_uses(root):
    globals = Counter()

    def cb_pre(node):
        if node.kind == LoafNodeKind.VAR and node.locality == LoafVarLocality.GLOBAL and node.name not in loaf_builtins:
            globals[node.name] += 1

    loaf_walk(root, cb_pre)
    return globals

def loaf_count_local_uses(root):
    locals = Counter()

    def cb_pre(node):
        if node.kind == LoafNodeKind.VAR and node.locality == LoafVarLocality.LOCAL:
            assert(node.var_obj is not None)
            locals[node.var_obj] += 1

    loaf_walk(root, cb_pre)
    return locals

def loaf_rename(root, globals, members, locals):
    def cb_pre(node):
        if node.kind == LoafNodeKind.PROPERTY and node.name in members:
            node.name = members[node.name]
        elif node.kind == LoafNodeKind.VAR and node.locality == LoafVarLocality.LOCAL:
            node.name = locals[node.var_obj]
        elif node.kind == LoafNodeKind.VAR and node.locality == LoafVarLocality.GLOBAL and node.name in globals:
            assert(node.name not in loaf_builtins)
            node.name = globals[node.name]
        elif node.kind == LoafNodeKind.FN:
            node.args = [locals[node.arg_objs[arg]] for arg in node.args]

    loaf_walk(root, cb_pre)

def loaf_write_string(root, is_code, omit_names=False):
    stack = [[]]

    def cb_pre(node):
        if node.children is not None:
            stack.append([])

    def cb_post(node):
        children = None
        if node.children is not None:
            children = stack.pop()

        if node.kind == LoafNodeKind.FN:
            stack[-1].append(f'(fn ({" ".join(node.args)}) {" ".join(children)})')
        elif node.kind == LoafNodeKind.SEQ:
            stack[-1].append(f'(seq {" ".join(children)})')
        elif node.kind == LoafNodeKind.QUOTE:
            stack[-1].append(f'(\' {" ".join(children)})')
        elif node.kind == LoafNodeKind.EXPR:
            stack[-1].append('(' + " ".join(children) + ')')
        elif node.kind == LoafNodeKind.VAR:
            if omit_names and node.name not in loaf_builtins:
                stack[-1].append(node.prefix)
            else:
                stack[-1].append(f'{node.prefix}{loaf_format_string(node.name)}')
        elif node.kind == LoafNodeKind.PROPERTY:
            if omit_names:
                stack[-1].append('')
            else:
                stack[-1].append(loaf_format_string(node.name))
        elif node.kind == LoafNodeKind.INTERP:
            stack[-1].append(f'`{children[0]}')
        elif node.kind == LoafNodeKind.LIST:
            stack[-1].append('(' + " ".join(children) + ')')
        elif node.kind == LoafNodeKind.DICT:
            stack[-1].append(f'{{{" ".join(children)}}}')
        elif node.kind == LoafNodeKind.DICT_ENTRY:
            stack[-1].append(f'{children[0]}={children[1]}')
        elif node.kind == LoafNodeKind.NUMBER:
            val = '0'
            if node.value != float(0):
                val = str(round(node.value, 5)).lstrip('0')
                if val[-2:] == '.0':
                    val = val[:-2]
            stack[-1].append(val)
        elif node.kind == LoafNodeKind.STRING:
            if (
                    all(c in 'abcdefghijklmnopqrstuvwxyz0123456789_/' for c in node.value.lower()) and
                    len(node.value) > 0 and
                    node.value[0].isalpha()
            ):
                stack[-1].append(node.value)
            else:
                stack[-1].append('"'+loaf_format_string(node.value)+'"')
        elif node.kind == LoafNodeKind.BOOLEAN:
            stack[-1].append('true' if node.value else 'false')
        elif node.kind == LoafNodeKind.NIL:
            stack[-1].append('nil')

    loaf_walk(root, cb_pre, cb_post)
    result = stack[0][0]
    if is_code:
        # strip implicit seq at top level
        if result[:4] == '(seq':
            result = result[4:].strip()[:-1].strip()
    return result


test_loaf_code_old='''
(set make_obj_cb (fn (n) (fn (o) ((@ $o $n) $o))))
(set rep (fn (n x)
 (let a (pack))
 (set q 7)
 (for 1 $n (fn () (add $a $x)))
 $a
))
(set b (' {q=5}))
(@= $b r 71)
(set q (+ 0 0))
(print (@ $b q))
(print (@ $b q oops))
'''

test_loaf_code='''
(set make_obj_cb (fn (n) (fn (o) ((@ $o $n) $o))))
(set rep (fn (n x)
 (let a (pack))
 (for 1 $n (fn () (add $a $x)))
 $a
))
(set id (fn (x) $x))
(set mcall (fn (obj m) ((@ $obj $m) $obj)))
'''

# parsed = loaf_parse(test_loaf_code, True)
# loaf_construct_scopes(parsed)
# loaf_print_indent(parsed)

# res=loaf_write_string(loaf_parse(test_loaf_code, True))
# res2=loaf_write_string(loaf_parse(res, True))
# print(res)
# print('---')
# print(res2)
# assert(res==res2)

# print('GLOBALS')
# globs=loaf_find_set_globals(loaf_parse('''
# (set make_obj_cb (fn (n) (fn (o) ((@ $o $n) $o))))
# (set rep (fn (n x)
#  (let a (pack))
#  (set q 7)
#  (for 1 $n (fn () (add $a $x)))
#  $a
# ))
# (set b (' {q=5}))
# ''', True))
# print(globs)
# 
# loaf_print_indent(loaf_parse('''
# {
#   pat_store={},
#   tick=1,
#   ptick={},
#   playing=false,
#   base_note_len=750,
#   note_len=750,
#   drum_sel=bd,
#   b0_bank=1,
#   b1_bank=1,
#   dr_bank=1,
#   song_mode=false,
#   patch={},
#   pat_seqs={},
#   pat_status={},
#   tl=`(timeline_new $default_patch),
#   pat_patch=`(copy $default_patch),
#  }
# ''', False))


class LoafLanguageBase(SubLanguageBase):
    # called to parse the sub-language from a string
    # (strings consist of raw pico-8 chars ('\0' to '\xff') - not real unicode)
    def __init__(self, text, is_code, on_error, **_):
        self.text = text
        self.is_code = is_code

        try:
            self.ast = loaf_parse(text, is_code)
            loaf_construct_scopes(self.ast)
        except LoafParseError as err:
            on_error(err)

    # for --lint:

    # called to get globals defined within the sub-language's code
    def get_defined_globals(self, **_):
        globs = loaf_find_set_globals(self.ast)
        yield from globs

    '''
    # called to lint the sub-language's code
    def lint(self, builtins, globals, on_error, **_):
        for stmt in self.stmts:
            for token in stmt:
                if self.is_global(token) and token not in builtins and token not in globals:
                    on_error("Identifier '%s' not found" % token)
        # could do custom lints too

    # for --minify:

'''
    # called to get all characters that won't get removed or renamed by the minifier
    # (aka, all characters other than whitespace and identifiers)
    # this is optional and doesn't affect correctness, but can slightly improve compressed size
    def get_unminified_chars(self, **_):
        yield from loaf_write_string(self.ast, self.is_code, omit_names=True)

    # called to get all uses of globals in the language's code
    def get_global_usages(self, **_):
        res = loaf_count_global_uses(self.ast)
        return res

    # called to get all uses of locals in the language's code
    def get_local_usages(self, **_):
        res = loaf_count_local_uses(self.ast)
        return res

    # called to get all uses of members (table keys) in the language's code
    def get_member_usages(self, **_):
        return loaf_count_property_uses(self.ast)

    # called to rename all uses of globals and members
    def rename(self, globals, members, locals, **_):
        loaf_rename(self.ast, globals, members, locals)

    # called (after rename) to return a minified string
    def minify(self, **_):
        # this gives false positives with renaming since the second parse is missing scopes
        # pt = str(self.ast)
        # res = loaf_write_string(self.ast, self.is_code)
        # pt2 = str(loaf_parse(res, self.is_code))
        # if pt != pt2:
        #     print('MISMATCH!!!!')
        #     print(self.text)
        #     print('-----------')
        #     print(res)
        #     print('-----------')
        #     print(pt)
        #     print('-----------')
        #     print(pt2)

        return loaf_write_string(self.ast, self.is_code)

class LoafLanguage(LoafLanguageBase):
    def __init__(self, text, on_error, **_):
        super().__init__(text, True, on_error)

class LoonLanguage(LoafLanguageBase):
    def __init__(self, text, on_error, **_):
        super().__init__(text, False, on_error)

