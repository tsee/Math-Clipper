#ifndef clipper_poly2av_h_
#define clipper_poly2av_h_

#include "myinit.h"

SV*
polygon2perl(pTHX_ const clipper::Polygon& poly)
{
  AV* av = newAV();
  AV* innerav;
  const unsigned int len = poly.size();
  av_extend(av, len-1);
  for (unsigned int i = 0; i < len; i++) {
    innerav = newAV();
    av_store(av, i, newRV_noinc((SV*)innerav));
    av_fill(innerav, 1);
    // IVSIZE is from perl/lib/CORE/config.h, defined as sizeof(IV)
#if IVSIZE >= 8
    // if Perl integers are 64 bit, use newSViv()
    av_store(innerav, 0, newSViv(poly[i].X));
    av_store(innerav, 1, newSViv(poly[i].Y));
#else
    // otherwise we expect Clipper integers to fit in the
	// 53 bit mantissa of a Perl double
    av_store(innerav, 0, newSVnv(poly[i].X));
    av_store(innerav, 1, newSVnv(poly[i].Y));
#endif


  }
  return (SV*)newRV_noinc((SV*)av);
}


SV*
polygons2perl(pTHX_ const clipper::Polygons& poly)
{
  AV* av = newAV();
  SV* innerav;
  const unsigned int len = poly.size();
  av_extend(av, len-1);
  for (unsigned int i = 0; i < len; i++) {
    innerav = polygon2perl(aTHX_ poly[i]);
    av_store(av, i, innerav);
  }
  return (SV*)newRV_noinc((SV*)av);
}


SV*
expolygon2perl(pTHX_ const clipper::ExPolygon& poly)
{
  HV* hv = newHV();
  hv_stores( hv, "outer", (SV*)polygon2perl(aTHX_ poly.outer) );
  hv_stores( hv, "holes", (SV*)polygons2perl(aTHX_ poly.holes) );
  return (SV*)newRV_noinc((SV*)hv);
}


SV*
expolygons2perl(pTHX_ const clipper::ExPolygons& polys)
{
  AV* av = newAV();
  SV* innerav;
  const unsigned int len = polys.size();
  av_extend(av, len-1);
  for (unsigned int i = 0; i < len; i++) {
    innerav = expolygon2perl(aTHX_ polys[i]);
    av_store(av, i, innerav);
  }
  return (SV*)newRV_noinc((SV*)av);
}



clipper::Polygon*
perl2polygon(pTHX_ AV* theAv)
{
  const unsigned int len = av_len(theAv)+1;
  clipper::Polygon* retval = new clipper::Polygon(len);
  SV** elem;
  AV* innerav;
  for (unsigned int i = 0; i < len; i++) {
    elem = av_fetch(theAv, i, 0);
    if (!SvROK(*elem)
        || SvTYPE(SvRV(*elem)) != SVt_PVAV
        || av_len((AV*)SvRV(*elem)) < 1)
    {
      delete retval;
      return NULL;
    }
    innerav = (AV*)SvRV(*elem);
    clipper::IntPoint& p = (*retval)[i];
    // IVSIZE is from perl/lib/CORE/config.h, defined as sizeof(IV)
#if IVSIZE >= 8
    // if Perl integers are 64 bit, use SvIV()
    // Clipper.pm then supports 64 bit ints.
    p.X = (clipper::long64)SvIV(*av_fetch(innerav, 0, 0));
    p.Y = (clipper::long64)SvIV(*av_fetch(innerav, 1, 0));
#else
    // otherwise coerce the Perl scalar to a double, with SvNV()
    // Perl doubles commonly allow 53 bits for the mantissa.
    // So in the common case, Clipper.pm supports 53 bit integers, stored in doubles on the Perl side.
    p.X = (clipper::long64)SvNV(*av_fetch(innerav, 0, 0));
    p.Y = (clipper::long64)SvNV(*av_fetch(innerav, 1, 0));
#endif
  }
  return retval;
}


clipper::Polygons*
perl2polygons(pTHX_ AV* theAv)
{
  const unsigned int len = av_len(theAv)+1;
  clipper::Polygons* retval = new clipper::Polygons(len);
  SV** elem;
  AV* innerav;
  for (unsigned int i = 0; i < len; i++) {
    elem = av_fetch(theAv, i, 0);
    if (!SvROK(*elem)
        || SvTYPE(SvRV(*elem)) != SVt_PVAV
        || av_len((AV*)SvRV(*elem)) < 1)
    {
      delete retval;
      return NULL;
    }
    innerav = (AV*)SvRV(*elem);
    clipper::Polygon* tmp = perl2polygon(aTHX_ innerav);
    if (tmp == NULL) {
      delete retval;
      return NULL;
    }
    (*retval)[i] = *tmp;
    delete tmp;
  }
  return retval;
}


#define AV_CHECK(outav, hv, key)                                                       \
    STMT_START {                                                                       \
      SV** buf = hv_fetchs(hv, key, 0);                                                \
      if (!buf || !*buf) {                                                             \
        croak("Missing ExPolygon hash key: '" key "' or not an array reference.");     \
      }                                                                                \
      SvGETMAGIC(*buf);                                                                \
      if (SvROK(*buf) && SvTYPE(SvRV(*buf)) == SVt_PVAV) {                             \
        outav = (AV*)SvRV(*buf);                                                       \
      }                                                                                \
      else {                                                                           \
        croak(key " is not an ARRAY reference");                                       \
      }                                                                                \
    } STMT_END

clipper::ExPolygon*
perl2expolygon(pTHX_ HV* theHv)
{
  AV* outerav;
  AV* holesav;
  AV_CHECK(outerav, theHv, "outer");
  AV_CHECK(holesav, theHv, "holes");

  clipper::ExPolygon* retval = new clipper::ExPolygon();
  clipper::Polygon* tmp = perl2polygon(aTHX_ outerav);
  if (!tmp) {
    delete retval;
    return NULL;
  }
  retval->outer = *tmp;

  clipper::Polygons* tmps = perl2polygons(aTHX_ holesav);
  if (!tmps) {
    delete retval;
    return NULL;
  }
  retval->holes = *tmps;

  return retval;
}
#undef AV_CHECK


clipper::ExPolygons*
perl2expolygons(pTHX_ AV* theAv)
{
  const unsigned int len = av_len(theAv)+1;
  std::vector<clipper::ExPolygon> tmpEx; // Done because of croak

  SV** elem;
  HV* innerhv;
  for (unsigned int i = 0; i < len; i++) {
    elem = av_fetch(theAv, i, 0);
    if (!SvROK(*elem)
        || SvTYPE(SvRV(*elem)) != SVt_PVHV)
      return NULL;
    innerhv = (HV*)SvRV(*elem);
    clipper::ExPolygon* tmp = perl2expolygon(aTHX_ innerhv);
    if (tmp == NULL)
      return NULL;
    tmpEx[i] = *tmp;
    delete tmp;
  }

  clipper::ExPolygons* retval = new clipper::ExPolygons(tmpEx);
  return retval;
}


#endif
