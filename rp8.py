import os
import sys

sys.path.append(os.getcwd())

from loaf import LoafLanguage, LoonLanguage

# this is called to get a sub-language class by name
def sublanguage_main(lang, **_):
    if lang == "loaf":
        return LoafLanguage
    if lang == "loon":
        return LoonLanguage

