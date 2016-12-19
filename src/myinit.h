#ifndef __clipper_myinit_h_
#define __clipper_myinit_h_

#include "clipper.hpp"

using namespace ClipperLib;

//-----------------------------------------------------------
// legacy code from Clipper documentation

typedef signed long long long64;

struct ExPolygon {
  ClipperLib::Path outer;
  ClipperLib::Paths holes;
};
 
typedef std::vector< ExPolygon > ExPolygons;
 
void AddOuterPolyNodeToExPolygons(ClipperLib::PolyNode& polynode, ExPolygons& expolygons)
{  
  size_t cnt = expolygons.size();
  expolygons.resize(cnt + 1);
  expolygons[cnt].outer = polynode.Contour;
  expolygons[cnt].holes.resize(polynode.ChildCount());
  for (int i = 0; i < polynode.ChildCount(); ++i)
  {
    expolygons[cnt].holes[i] = polynode.Childs[i]->Contour;
    //Add outer polygons contained by (nested within) holes ...
    for (int j = 0; j < polynode.Childs[i]->ChildCount(); ++j)
      AddOuterPolyNodeToExPolygons(*polynode.Childs[i]->Childs[j], expolygons);
  }
}
 
void PolyTreeToExPolygons(ClipperLib::PolyTree& polytree, ExPolygons& expolygons)
{
  expolygons.clear();
  for (int i = 0; i < polytree.ChildCount(); ++i)
    AddOuterPolyNodeToExPolygons(*polytree.Childs[i], expolygons);
}
//-----------------------------------------------------------

#include "poly2av.h"
#include "offset.h"

enum ZFillType { zftNone, zftMax, zftMin, zftBothMax, zftBothMin, zftInterpolateMean, zftBothUInt32, zftAllUInt16, zftBothUInt31Flags };
#ifdef use_xyz
#include "zfill.h"
#define CLIPPER_HAS_Z 1
#else
#define CLIPPER_HAS_Z 0
#endif

#endif
