/* $Id: MeCab.xs 2 2006-05-02 02:11:10Z daisuke $
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

#define GETOPT_PVN(opts, name, mecab_name) \
    svr = hv_fetch(opts, name, strlen(name), 0); \
    if (svr != NULL) { \
        tmp = SvPV(*svr, len); \
        Newz(1234, argv[argc], strlen(mecab_name) + len + 3, char); \
        sprintf(argv[argc++], "--%s=%s", mecab_name, tmp); \
    }

#define GETOPT_PV(opts, name) \
    GETOPT_PVN(opts, name, name)

#define GETOPT_BOOLN(opts, name, mecab_name) \
    svr = hv_fetch(opts, name, strlen(name), 0); \
    if (svr != NULL && SvTRUE(*svr)) { \
        Newz(1234, argv[argc], strlen(mecab_name) + 2, char); \
        sprintf(argv[argc++], "--%s", mecab_name); \
    }

#define GETOPT_BOOL(opts, name) \
    GETOPT_BOOLN(opts, name, name)
        
static void
init_constants()
{
    HV *stash;

    stash = gv_stashpv("Text::MeCab::Node", 1);
    newCONSTSUB(stash, "MECAB_NOR_NODE", newSViv(MECAB_NOR_NODE));
    newCONSTSUB(stash, "MECAB_UNK_NODE", newSViv(MECAB_UNK_NODE));
    newCONSTSUB(stash, "MECAB_BOS_NODE", newSViv(MECAB_BOS_NODE));
    newCONSTSUB(stash, "MECAB_EOS_NODE", newSViv(MECAB_EOS_NODE));
}

MODULE = Text::MeCab               PACKAGE = Text::MeCab

PROTOTYPES: ENABLE

BOOT:
    init_constants();

SV *
new(class, opts = NULL)
        SV *class;
        HV *opts;
    INIT:
        SV *sv;
        SV **svr;
        char     *tmp;
        char    **argv;
        int       argc;
        int       i;
        mecab_t  *mecab;
        STRLEN    len;
    CODE:
        if (opts != NULL) {
            argc = 0;
            /* MAX argv size = 16 */
            Newz(1234, argv, MECAB_ARGV_MAX, char *);
 
            GETOPT_PV(opts, "rcfile");
            GETOPT_PV(opts, "dicdir");
            GETOPT_PV(opts, "userdir");
            GETOPT_PVN(opts, "lattice_level", "lattice-level");
            GETOPT_BOOLN(opts, "all_morphs", "all-morphs");
            GETOPT_PVN(opts, "output_format_type", "output-format-type");
            GETOPT_BOOL(opts, "partial");
            GETOPT_PVN(opts, "node_format", "node-format");
            GETOPT_PVN(opts, "unk_format", "unk-format");
            GETOPT_PVN(opts, "bos_format", "bos-format");
            GETOPT_PVN(opts, "eos_format", "eos-format");
            GETOPT_PVN(opts, "input_buffer_size", "input-buffer-size");
            GETOPT_BOOLN(opts, "allocate_sentence", "allocate-sentence");
            GETOPT_PV(opts, "nbest");
            GETOPT_PV(opts, "theta");
        }

        mecab = mecab_new(argc, argv);
        if (opts != NULL) {
            for(i = 0; i < MECAB_ARGV_MAX; i++)
                Safefree(argv[i]);

            Safefree(argv);
        }

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
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->rlength);
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
        RETVAL = newSVpv(node->feature, 0);
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

        RETVAL = newSVpv(node->surface, node->length);
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
    OUTPUT:
        RETVAL

SV *
bnext(self)
        SV *self;
    INIT:
        SV *sv;
        mecab_node_t *node;
    CODE:
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
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->rcAttr);
    OUTPUT:
        RETVAL

SV *
lcattr(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->lcAttr);
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
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->isbest == 1 ? &PL_sv_yes : &PL_sv_no;
    OUTPUT:
        RETVAL

SV *
alpha(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVnv(node->alpha);
    OUTPUT:
        RETVAL

SV *
beta(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVnv(node->beta);
    OUTPUT:
        RETVAL

SV *
prob(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVnv(node->prob);
    OUTPUT:
        RETVAL


SV *
wcost(self)
        SV *self;
    INIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->wcost);
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


