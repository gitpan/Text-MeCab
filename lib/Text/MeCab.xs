/* $Id: MeCab.xs 4 2006-05-02 04:38:09Z daisuke $
 *
 * Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
 * All rights reserved.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "mecab.h"

#define XS_STATE(type, x) \
    INT2PTR(type, SvROK(x) ? SvIV(SvRV(x)) : SvIV(x))

#define MECAB_ARGV_MAX 16

static void
init_constants()
{
    HV *stash;
    stash = gv_stashpv("Text::MeCab", 1);

    newCONSTSUB(stash, "MECAB_VERSION", newSVnv(MECAB_MAJOR_VERSION + MECAB_MINOR_VERSION / 100.0));
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
    newCONSTSUB(stash, "MECAB_NOR_NODE", newSViv(MECAB_NOR_NODE));
    newCONSTSUB(stash, "MECAB_UNK_NODE", newSViv(MECAB_UNK_NODE));
    newCONSTSUB(stash, "MECAB_BOS_NODE", newSViv(MECAB_BOS_NODE));
    newCONSTSUB(stash, "MECAB_EOS_NODE", newSViv(MECAB_EOS_NODE));
#endif
}

MODULE = Text::MeCab               PACKAGE = Text::MeCab

PROTOTYPES: ENABLE

BOOT:
    init_constants();

SV *
xs_new(class, args)
        SV *class;
        AV *args;
    INIT:
        SV *sv;
        SV **svr;
        char **argv;
        mecab_t *mecab;
        int i;
        int len;
    CODE:
        len = av_len(args) + 1;
        Newz(1234, argv, len + 1, char *);
    
        for(i = 0; i < len; i++) {
            svr = av_fetch(args, i, 0);
            if (svr == NULL) {
                Safefree(argv);
                croak("bad index");
            }
    
            if (SvROK(*svr)) {
                Safefree(argv);
                croak("arguments must be simple scalars");
            }

            argv[i] = SvPV_nolen(*svr);
        }
        argv[i] = "--allocate-sentence";

        mecab = mecab_new(len, argv);
        Safefree(argv);

        sv = newSViv(PTR2IV(mecab));
        sv = newRV_noinc(sv);
        sv_bless(sv, gv_stashpv(SvPV_nolen(class), 1));
        SvREADONLY_on(sv);

        RETVAL = sv;
    OUTPUT:
        RETVAL

SV *
parse(self, text)
        SV *self;
        SV *text;
    INIT:
        SV *sv;
        mecab_t *mecab;
        mecab_node_t *node;
        char    *input;
        STRLEN   len;
    CODE:
        mecab = XS_STATE(mecab_t *, self);
        input = SvPV(text, len);
        if (len <= 0)
            return XSRETURN_UNDEF;

        node = mecab_sparse_tonode(mecab, input);

        sv = newSViv(PTR2IV(node));
        sv = newRV_noinc(sv);
        sv_bless(sv, gv_stashpv("Text::MeCab::Node", 1));
        SvREADONLY_on(sv);

        RETVAL = sv;
    OUTPUT:
        RETVAL

void
DESTROY(self)
        SV *self;
    INIT:
        mecab_t *mecab;
    CODE:
        mecab = XS_STATE(mecab_t *, self);
        mecab_destroy(mecab);

MODULE = Text::MeCab    PACKAGE = Text::MeCab::Node

PROTOTYPES: ENABLE

SV *
id(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->id);
    OUTPUT:
        RETVAL

SV *
length(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->length);
    OUTPUT:
        RETVAL

SV *
rlength(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->rlength);
#else
        croak("rlength() is not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
feature(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVpvf("%s",node->feature);
    OUTPUT:
        RETVAL

SV *
surface(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVpvf("%s", node->surface);
    OUTPUT:
        RETVAL

SV *
next(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);

        if (node->next == NULL) {
            sv = &PL_sv_undef;
        } else {
            sv = newSViv(PTR2IV(node->next));
            sv = newRV_noinc(sv);
            sv_bless(sv, gv_stashpv("Text::MeCab::Node", 1));
            SvREADONLY_on(sv);
        }

        RETVAL = sv;
    OUTPUT:
        RETVAL

SV *
enext(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        if (node->enext == NULL) {
            sv = &PL_sv_undef;
        } else {
            sv = newSViv(PTR2IV(node->enext));
            sv = newRV_noinc(sv);
            sv_bless(sv, gv_stashpv("Text::MeCab::Node", 1));
            SvREADONLY_on(sv);
        }

        RETVAL = sv;
#else
        croak("enext() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
bnext(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        if (node->bnext == NULL) {
            sv = &PL_sv_undef;
        } else {
            sv = newSViv(PTR2IV(node->bnext));
            sv = newRV_noinc(sv);
            sv_bless(sv, gv_stashpv("Text::MeCab::Node", 1));
            SvREADONLY_on(sv);
        }

        RETVAL = sv;
#else
        croak("bnext() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
prev(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        if (node->prev == NULL) {
            sv = &PL_sv_undef;
        } else {
            sv = newSViv(PTR2IV(node->prev));
            sv = newRV_noinc(sv);
            sv_bless(sv, gv_stashpv("Text::MeCab::Node", 1));
            SvREADONLY_on(sv);
        }

        RETVAL = sv;
    OUTPUT:
        RETVAL

SV *
rcattr(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->rcAttr);
#else
        croak("rcattr() not availabel for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
lcattr(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->lcAttr);
#else
        croak("lcattr() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
stat(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->stat);
    OUTPUT:
        RETVAL

SV *
isbest(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->isbest == 1 ? &PL_sv_yes : &PL_sv_no;
#else
        croak("isbest() not availale for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
alpha(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVnv(node->alpha);
#else
        croak("alpha() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
beta(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVnv(node->beta);
#else
        croak("beta() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
prob(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVnv(node->prob);
#else
        croak("prob() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
wcost(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->wcost);
#else
        croak("wcost() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
cost(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->cost);
    OUTPUT:
        RETVAL
