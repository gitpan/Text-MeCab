/* $Id: /mirror/Text-MeCab/trunk/lib/Text/MeCab.xs 124 2006-06-09T01:15:41.678498Z daisuke  $
 *
 * Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
 * All rights reserved.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define NEED_newCONSTSUB
#define NEED_newRV_noinc
#define NEED_sv_2pv_nolen
#include "ppport.h"
#include "mecab.h"

#define XS_STATE(type, x) \
    INT2PTR(type, SvROK(x) ? SvIV(SvRV(x)) : SvIV(x))

typedef struct _xs_mecab_node_t {
  IV     refcnt;
  struct _xs_mecab_node_t  *prev;
  struct _xs_mecab_node_t  *next;
/* Currently Unsupported */
/*
  struct mecab_node_t  *enext; 
  struct mecab_node_t  *bnext;
  struct mecab_path_t  *rpath;
  struct mecab_path_t  *lpath;
*/
  char  *surface;
  char  *feature;
  unsigned int   id;
  unsigned short length;      /* length of morph */
  unsigned char  stat;
  long           cost; 
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
  unsigned short rlength;     /* real length of morph (include white space before the morph) */
  unsigned short rcAttr;
  unsigned short lcAttr;
  unsigned short posid;
  unsigned char  char_type;
  unsigned char  isbest;
  float          alpha;
  float          beta;
  float          prob;
  short          wcost;
#endif
} xs_mecab_node_t;

xs_mecab_node_t *
deep_node_copy(mecab_node_t *node)
{
    xs_mecab_node_t *xs_node;
    if (node == NULL)
        return NULL;

    Newz(1234, xs_node, 1, xs_mecab_node_t);

    if (node->length <= 0)
        xs_node->surface = NULL;
    else {
        Newz(1234, xs_node->surface, node->length + 1, char);
        Copy(node->surface, xs_node->surface, node->length, char);
        *(xs_node->surface + node->length) = '\0';
    }

    Newz(1234, xs_node->feature, strlen(node->feature), char);
    Copy(node->feature, xs_node->feature, strlen(node->feature), char);

    xs_node->id        = node->id;
    xs_node->length    = node->length;
    xs_node->stat      = node->stat;
    xs_node->cost      = node->cost;
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
    xs_node->rlength   = node->rlength;
    xs_node->rcAttr    = node->rcAttr;
    xs_node->lcAttr    = node->lcAttr;
    xs_node->posid     = node->posid;
    xs_node->char_type = node->char_type;
    xs_node->isbest    = node->isbest;
    xs_node->alpha     = node->alpha;
    xs_node->prob      = node->prob;
    xs_node->wcost     = node->wcost;
#endif
    xs_node->next = NULL;
    xs_node->prev = NULL;

    xs_node->next = deep_node_copy(node->next);
    if (xs_node->next != NULL)
        xs_node->next->prev = xs_node;
    return xs_node;
}

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
xs_new(class, args = NULL)
        SV *class;
        AV *args;
    PREINIT:
        SV *sv;
        SV **svr;
        char **argv;
        mecab_t *mecab;
        int i;
        int len;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        av_push(args, newSVpv("--allocate-sentence", 0));
#endif
        len = av_len(args) + 1;
        
        Newz(1234, argv, len, char *);

        for(i = 0; i < len; i++) {
            svr = av_fetch(args, i, 0);
            if (svr == NULL) {
                Safefree(argv);
                croak("bad index %d", i);
            }
    
            if (SvROK(*svr)) {
                Safefree(argv);
                croak("arguments must be simple scalars");
            }

            argv[i + 1] = SvPV_nolen(*svr);
        }
        argv[0] = "perl-Text-MeCab";

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
    PREINIT:
        SV *sv;
        mecab_t *mecab;
        mecab_node_t *node;
        xs_mecab_node_t *xs_node;
        char    *input;
        STRLEN   len;
        int      node_max;
    CODE:
        mecab = XS_STATE(mecab_t *, self);
        input = SvPV(text, len);

        if (len <= 0)
            XSRETURN_UNDEF;

        node = mecab_sparse_tonode(mecab, input);
        if (! node) {
            croak("mecab returned with error: %s", mecab_strerror(mecab));
        }

        xs_node = deep_node_copy(node);
        xs_node->refcnt = 1;

        sv = newSViv(PTR2IV(xs_node));
        sv = newRV_noinc(sv);
        sv_bless(sv, gv_stashpv("Text::MeCab::Node", 1));
        SvREADONLY_on(sv);

        RETVAL = sv;
    OUTPUT:
        RETVAL

void
DESTROY(self)
        SV *self;
    PREINIT:
        mecab_t *mecab;
    CODE:
        mecab = XS_STATE(mecab_t *, self);
        mecab_destroy(mecab);

MODULE = Text::MeCab    PACKAGE = Text::MeCab::Node

PROTOTYPES: ENABLE

SV *
id(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->id);
    OUTPUT:
        RETVAL

SV *
length(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->length);
    OUTPUT:
        RETVAL

SV *
rlength(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->rlength);
#else
        croak("rlength() is not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
feature(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSVpvf("%s",node->feature);
    OUTPUT:
        RETVAL

SV *
surface(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);
        if (node->length > 0)
            RETVAL = newSVpvf("%s", node->surface);
        else
            RETVAL = newSVpv("", 0);
    OUTPUT:
        RETVAL

SV *
next(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
        xs_mecab_node_t *head;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);

        if (node->next == NULL) {
            sv = &PL_sv_undef;
        } else {
            head = node;
            while (head->prev)
                head = head->prev;
            head->refcnt++;

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
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
    CODE:
        croak("Currently enext() unsupported");
    OUTPUT:
        RETVAL

SV *
bnext(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
    CODE:
        croak("Currently bnext() unsupported");
    OUTPUT:
        RETVAL

SV *
prev(self)
        SV *self;
    PREINIT:
        SV *sv;
        xs_mecab_node_t *node;
        xs_mecab_node_t *head;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);
        if (node->prev == NULL) {
            sv = &PL_sv_undef;
        } else {
            head = node;
            while (head->prev)
                head = head->prev;
            head->refcnt++;

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
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->rcAttr);
#else
        croak("rcattr() not availabel for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
lcattr(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->lcAttr);
#else
        croak("lcattr() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
stat(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->stat);
    OUTPUT:
        RETVAL

SV *
isbest(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = node->isbest == 1 ? &PL_sv_yes : &PL_sv_no;
#else
        croak("isbest() not availale for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
alpha(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSVnv(node->alpha);
#else
        croak("alpha() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
beta(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSVnv(node->beta);
#else
        croak("beta() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
prob(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSVnv(node->prob);
#else
        croak("prob() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
wcost(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->wcost);
#else
        croak("wcost() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
cost(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *node;
    CODE:
        node = XS_STATE(xs_mecab_node_t *, self);
        RETVAL = newSViv(node->cost);
    OUTPUT:
        RETVAL

void
DESTROY(self)
        SV *self;
    PREINIT:
        xs_mecab_node_t *xs_node;
        xs_mecab_node_t *tmp;
    CODE:
        xs_node = XS_STATE(xs_mecab_node_t *, self);
        if (xs_node->prev == NULL)
            tmp = xs_node;
        else {
            tmp = xs_node;
            while (tmp->prev != NULL) {
                tmp = tmp->prev;
            }
        }

        tmp->refcnt--;
        if (tmp->refcnt == 0)
            while (tmp != NULL) {
                xs_node = tmp->next;
                Safefree(tmp);
                tmp = xs_node;
            }

