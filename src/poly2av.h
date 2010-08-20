#ifndef __clipper_poly2av_h_
#define __clipper_poly2av_h_

#include "clipper.hpp"

SV*
poly2rvav(pTHX_ const clipper::TPolygon& poly)
{
  AV* av = newAV();
  AV* innerav;
  const unsigned int len = poly.size();
  av_extend(av, len-1);
  for (unsigned int i = 0; i < len; i++) {
    innerav = newAV();
    av_store(av, i, newRV_noinc((SV*)innerav));
    av_fill(innerav, 1);
    av_store(innerav, 0, newSVnv(poly[i].X));
    av_store(innerav, 1, newSVnv(poly[i].Y));
  }
  return (SV*)newRV_noinc((SV*)av);
}


SV*
polypoly2rvav(pTHX_ const clipper::TPolyPolygon& poly)
{
  AV* av = newAV();
  SV* innerav;
  const unsigned int len = poly.size();
  av_extend(av, len-1);
  for (unsigned int i = 0; i < len; i++) {
    innerav = poly2rvav(aTHX_ poly[i]);
    av_store(av, i, innerav);
  }
  return (SV*)newRV_noinc((SV*)av);
}

clipper::TPolygon*
av2poly(pTHX_ AV* theAv)
{
  const unsigned int len = av_len(theAv)+1;
  clipper::TPolygon* retval = new clipper::TPolygon(len);
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
    clipper::TDoublePoint& p = (*retval)[i];
    p.X = SvNV(*av_fetch(innerav, 0, 0));
    p.Y = SvNV(*av_fetch(innerav, 1, 0));
  }
  return retval;
}

clipper::TPolyPolygon*
av2polypoly(pTHX_ AV* theAv)
{
  const unsigned int len = av_len(theAv)+1;
  clipper::TPolyPolygon* retval = new clipper::TPolyPolygon(len);
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
    clipper::TPolygon* tmp = av2poly(aTHX_ innerav);
    if (tmp == NULL) {
      delete retval;
      return NULL;
    }
    (*retval)[i] = *tmp;
    delete tmp;
  }
  return retval;
}
#endif
