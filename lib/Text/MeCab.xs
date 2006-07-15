/* $Id: /mirror/Text-MeCab/trunk/lib/Text/MeCab.xs 2079 2006-07-15T03:24:27.238091Z daisuke  $
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

#define XS_STRUCT2OBJ(sv, class, obj) \
    sv = newSViv(PTR2IV(obj));  \
    sv = newRV_noinc(sv); \
    sv_bless(sv, gv_stashpv(class, 1)); \
    SvREADONLY_on(sv);

/* Deep Copy Memory Management Strategy:
 *
 * When we call dclone(), we actually clone the *entire* node list.
 * that is, we go back to the first node in the list, and start from
 * there.
 *
 * When ->next, ->prev is called, we update the node->head struct's
 * refcnt. When this refcnt is zero, we finally free the struct
 */

typedef struct _pmecab_node_clone_t {
  struct _pmecab_node_clone_t  *prev;
  struct _pmecab_node_clone_t  *next;
  struct _pmecab_node_clone_head_t *head;
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
} pmecab_node_clone_t;

typedef struct _pmecab_node_clone_head_t {
    IV refcnt;
    pmecab_node_clone_t *first;
} pmecab_node_clone_head_t;

void
pmecab_free_node(pmecab_node_clone_t *node)
{
    pmecab_node_clone_head_t *head;
    pmecab_node_clone_t      *tmp;

    if (node == NULL || node->head == NULL) { /* sanity */
        return;
    }

    head = node->head;
    head->refcnt--;

    if (head->refcnt > 0)
        return;

    node = head->first;
    while (node != NULL) {
        tmp = node->next;
        Safefree(node);
        node = tmp;
    }
    Safefree(head);
}

pmecab_node_clone_t *
pmecab_clone_node(mecab_node_t *node)
{
    pmecab_node_clone_t *xs_node;
    Newz(1234, xs_node, 1, pmecab_node_clone_t);
    if (node->length <= 0)
        xs_node->surface = NULL;
    else {
        int len = node->length;
        /* node->length is actually unsigned short, but what the heck.
         * just case it off to an int.
         */
        Newz(1234, xs_node->surface, len + 1, char);
        Copy(node->surface, xs_node->surface, len, char);
        *(xs_node->surface + len) = '\0';
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

    return xs_node;
}

pmecab_node_clone_t *
pmecab_deep_clone_node(mecab_node_t *node)
{
    pmecab_node_clone_head_t *xs_head;
    pmecab_node_clone_t *xs_node;
    pmecab_node_clone_t *cur_xs_node;
    pmecab_node_clone_t *tmp_xs;
    mecab_node_t *cur_node;
    mecab_node_t *tmp;
    if (node == NULL)
        return NULL;

    /* First, create the clone node list head. Then create the node that 
     * requested to be cloned.
     */
    Newz(1234, xs_head, 1, pmecab_node_clone_head_t);

    xs_node = pmecab_clone_node(node);
    xs_node->head = xs_head;

    cur_node = node->prev;
    cur_xs_node = xs_node;
    while (cur_node != NULL) {
        tmp = cur_node->prev;
        tmp_xs = pmecab_clone_node(cur_node);
        tmp_xs->head = xs_head;

        if (tmp == NULL) {
            xs_head->first = tmp_xs;
        }

        cur_xs_node->prev = tmp_xs;
        tmp_xs->next = cur_xs_node;

        cur_node = tmp;
        cur_xs_node = tmp_xs;
    }

    cur_node    = node;
    cur_xs_node = xs_node;
    while (cur_node != NULL) {
        tmp = cur_node->next;
        tmp_xs = pmecab_clone_node(cur_node);
        tmp_xs->head = xs_head;
        cur_xs_node->next = tmp_xs;
        tmp_xs->prev = cur_xs_node;

        cur_node = tmp;
        cur_xs_node = tmp_xs;
    }

    xs_head->refcnt++;

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
        char *class;
        AV *args;
    PREINIT:
        SV *sv;
        SV **svr;
        char **argv = NULL;
        mecab_t *mecab;
        int i;
        int len;
    CODE:
#if 0
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        av_push(args, newSVpv("--allocate-sentence", 0));
#endif
#endif
        len = av_len(args) + 1;
#if MECAB_MAJOR_VERSION == 0 && MECAB_MINOR_VERSION < 92
        Newz(1234, argv, len + 1, char *);
        for(i = 0; i < len; i++) {
#else
        if (len > 0)
            Newz(1234, argv, len, char*);
        for(i = 0; i < len; i++) {
#endif
            svr = av_fetch(args, i, 0);
            if (svr == NULL) {
                Safefree(argv);
                croak("bad index %d", i);
            }
    
            if (SvROK(*svr)) {
                Safefree(argv);
                croak("arguments must be simple scalars");
            }
#if MECAB_MAJOR_VERSION == 0 && MECAB_MINOR_VERSION < 92
            argv[i + 1] = SvPV_nolen(*svr);
        }
        argv[0] = "perl-Text-MeCab";
#else
            argv[i] = SvPV_nolen(*svr);
        }
#endif
        mecab = mecab_new(len, argv);
        if (mecab == NULL)
            croak ("Failed to create mecab instance");

        if (len > 0)
            Safefree(argv);
        XS_STRUCT2OBJ(sv, class, mecab);
        RETVAL = sv;
    OUTPUT:
        RETVAL

SV *
parse(self, text)
        SV *self;
        char *text;
    PREINIT:
        SV *sv;
        mecab_t *mecab;
        mecab_node_t *node;
    CODE:
        mecab = XS_STATE(mecab_t *, self);
        node = mecab_sparse_tonode(mecab, text);
        if (node == NULL) {
            croak("mecab returned with error: %s", mecab_strerror(mecab));
        }

        XS_STRUCT2OBJ(sv, "Text::MeCab::Node", node);
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
dclone(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
        pmecab_node_clone_t *xs_node;
        SV *sv;
    CODE:
        node    = XS_STATE(mecab_node_t *, self);
        xs_node = pmecab_deep_clone_node(node);
        XS_STRUCT2OBJ(sv, "Text::MeCab::Node::Cloned", xs_node);
        RETVAL = sv;
    OUTPUT:
        RETVAL

unsigned int
id(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->id;
    OUTPUT:
        RETVAL

unsigned int
length(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->length;
    OUTPUT:
        RETVAL

unsigned int
rlength(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->rlength;
#else
        croak("rlength() is not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
feature(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSVpvf("%s",node->feature);
    OUTPUT:
        RETVAL

SV *
surface(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        if (node == NULL)
            RETVAL = &PL_sv_undef;
        else  {
            if (node->length > 0) {
                RETVAL = newSVpvn(node->surface, node->length);
            } else {
                RETVAL = newSVpv("", 0);
            }
        }
    OUTPUT:
        RETVAL

SV *
next(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
        SV *sv;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        if (node->next == NULL)
            XSRETURN_UNDEF;
        else
            XS_STRUCT2OBJ(sv, "Text::MeCab::Node", node->next);
        RETVAL = sv;
    OUTPUT:
        RETVAL 

SV *
prev(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
        SV *sv;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        if (node->prev == NULL)
            XSRETURN_UNDEF;
        else
            XS_STRUCT2OBJ(sv, "Text::MeCab::Node", node->prev);
        RETVAL = sv;
    OUTPUT:
        RETVAL

unsigned short
rcattr(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->rcAttr;
#else
        croak("rcattr() not availabel for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

unsigned short
lcattr(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->lcAttr;
#else
        croak("lcattr() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

unsigned short
posid(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->posid;
#else
        croak("posid() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

unsigned char
char_type(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->char_type;
#else
        croak("char_type() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
stat(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = newSViv(node->stat);
    OUTPUT:
        RETVAL

SV *
isbest(self)
        SV *self;
    PREINIT:
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

float
alpha(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->alpha;
#else
        croak("alpha() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

float
beta(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->beta;
#else
        croak("beta() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

float
prob(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->prob;
#else
        croak("prob() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

short
wcost(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->wcost;
#else
        croak("wcost() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

long
cost(self)
        SV *self;
    PREINIT:
        mecab_node_t *node;
    CODE:
        node = XS_STATE(mecab_node_t *, self);
        RETVAL = node->cost;
    OUTPUT:
        RETVAL

MODULE = Text::MeCab    PACKAGE = Text::MeCab::Node::Cloned

PROTOTYPES: ENABLE

unsigned int
id(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->id;
    OUTPUT:
        RETVAL

unsigned int
length(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->length;
    OUTPUT:
        RETVAL

unsigned int
rlength(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->rlength;
#else
        croak("rlength() is not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
feature(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = newSVpvf("%s",node->feature);
    OUTPUT:
        RETVAL

SV *
surface(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);
        if (node == NULL)
            croak("Internal Text::MeCab::Node::Cloned struct is corrupted?");

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
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);

        if (node->next == NULL) {
            XSRETURN_UNDEF;
        } else {
            node->head->refcnt++;
            XS_STRUCT2OBJ(sv, "Text::MeCab::Node::Cloned", node->next);
        }
        RETVAL = sv;
    OUTPUT:
        RETVAL

void
enext()
    CODE:
        croak("Currently enext() unsupported");

void
bnext()
    CODE:
        croak("Currently bnext() unsupported");

SV *
prev(self)
        SV *self;
    PREINIT:
        SV *sv;
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);
        if (node->prev == NULL) {
            XSRETURN_UNDEF;
        } else {
            node->head->refcnt++;
            XS_STRUCT2OBJ(sv, "Text::MeCab::Node::Cloned", node->prev);
        }

        RETVAL = sv;
    OUTPUT:
        RETVAL

unsigned short
rcattr(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->rcAttr;
#else
        croak("rcattr() not availabel for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

unsigned short
lcattr(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->lcAttr;
#else
        croak("lcattr() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

unsigned short
posid(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->posid;
#else
        croak("posid() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

unsigned char
char_type(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->char_type;
#else
        croak("char_type() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

SV *
stat(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = newSViv(node->stat);
    OUTPUT:
        RETVAL

SV *
isbest(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->isbest == 1 ? &PL_sv_yes : &PL_sv_no;
#else
        croak("isbest() not availale for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

float
alpha(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->alpha;
#else
        croak("alpha() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

float
beta(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->beta;
#else
        croak("beta() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

float
prob(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->prob;
#else
        croak("prob() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

short
wcost(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
#if MECAB_MAJOR_VERSION > 0 || MECAB_MINOR_VERSION >= 90
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->wcost;
#else
        croak("wcost() not available for mecab < 0.90");
#endif
    OUTPUT:
        RETVAL

long
cost(self)
        SV *self;
    PREINIT:
        pmecab_node_clone_t *node;
    CODE:
        node = XS_STATE(pmecab_node_clone_t *, self);
        RETVAL = node->cost;
    OUTPUT:
        RETVAL

void
DESTROY(self)
        SV *self;
    CODE:
        pmecab_free_node(XS_STATE(pmecab_node_clone_t *, self));

