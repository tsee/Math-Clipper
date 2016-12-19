#ifndef clipper_offset_h_
#define clipper_offset_h_

#include "myinit.h"

void
_scale_polygons(ClipperLib::Paths* polygons, const double scale)
{
    for (ClipperLib::Paths::size_type i = 0; i != (*polygons).size(); i++) {
        ClipperLib::Path* mypoly = &(*polygons)[i];
        for (ClipperLib::Path::size_type j = 0; j != (*mypoly).size(); j++) {
            (*mypoly)[j].X *= scale;
            (*mypoly)[j].Y *= scale;
        }
    }
}

ClipperLib::Paths*
_int_offset(ClipperLib::Paths* polygons, const float delta, const double scale, ClipperLib::JoinType jointype, const double MiterLimit, ClipperLib::EndType endtype)
{
    // scale
    _scale_polygons(polygons, scale);
    
    // perform offset
    ClipperLib::Paths* retval = new ClipperLib::Paths();
    //ClipperLib::OffsetPaths(*polygons, *retval, (delta*scale), jointype, MiterLimit);
    ClipperLib::ClipperOffset co;
    co.MiterLimit = MiterLimit;
    co.AddPaths(*polygons, jointype, endtype);
    co.Execute(*retval, (delta*scale));
    
    // unscale
    _scale_polygons(retval, 1/scale);
    
    return retval;
}

#endif
