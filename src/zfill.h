#ifndef clipper_zfill_h_
#define clipper_zfill_h_

#define ZMARK -1;
//#include <iostream>

typedef unsigned long long cUInt;

void zfill_mark(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  pt.Z = ZMARK;
}

// The average of the interpolated Z values on each edge at the intersection.
void zfill_average_interpolate_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  cInt d1 = sqrt(pow(e1top.X - e1bot.X,2) + pow(e1top.Y - e1bot.Y,2));
  cInt d2 = sqrt(pow(e2top.X - e2bot.X,2) + pow(e2top.Y - e2bot.Y,2));
  cInt factor1 = sqrt(pow(   pt.X - e1bot.X,2) + pow(   pt.Y - e1bot.Y,2)) / d1;
  cInt factor2 = sqrt(pow(   pt.X - e2bot.X,2) + pow(   pt.Y - e2bot.Y,2)) / d2;

  // One of those will typically have more precision than the other, so we
  // take the average to improve the average result, rather than always 
  // relying on one or the other.
  // (The alternative would be to figure which will give better results 
  // on its own.) 
  // If Zs are geometric coordinates, this interpolation probably makes
  // the most sense when both edges are on the same flat plane.
  // If the edges are not on the same plane, but at least one the edges
  // comes from a planar polygon or path, this average Z will convey
  // the distance between that edge's plane and the other edge. That is,
  // it will protrude from that plane by half the distance to the intersection
  // of the other edge. If you expect planar results, these out-of-plane Zs can
  // possibly help construct effects like projection, shadow casting, or 2.5D 
  // vertical extrusions.

  pt.Z = (  (e1bot.Z + (e1top.Z - e1bot.Z) * factor1)
          + (e2bot.Z + (e2top.Z - e2bot.Z) * factor2)
         ) / 2;
}

// Intersection Z ends up closer to longer edge's interpolated Z
void zfill_weighted_average_interpolate_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  cInt d1 = sqrt(pow(e1top.X - e1bot.X,2) + pow(e1top.Y - e1bot.Y,2));
  cInt d2 = sqrt(pow(e2top.X - e2bot.X,2) + pow(e2top.Y - e2bot.Y,2));
  cInt p1 = sqrt(pow(   pt.X - e1bot.X,2) + pow(   pt.Y - e1bot.Y,2));
  cInt p2 = sqrt(pow(   pt.X - e2bot.X,2) + pow(   pt.Y - e2bot.Y,2));
  cInt factor1 = p1 / d1;
  cInt factor2 = p2 / d2;
  pt.Z = (  (e1bot.Z * d1 + (e1top.Z - e1bot.Z) * p1)
          + (e2bot.Z * d2 + (e2top.Z - e2bot.Z) * p2)
         ) / (d1 + d2);
}

// Intersection Z ends up closer to shorter edge's interpolated Z
void zfill_inverse_weighted_average_interpolate_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  cInt d1 = sqrt(pow(e1top.X - e1bot.X,2) + pow(e1top.Y - e1bot.Y,2));
  cInt d2 = sqrt(pow(e2top.X - e2bot.X,2) + pow(e2top.Y - e2bot.Y,2));
  cInt factor1 = sqrt(pow(   pt.X - e1bot.X,2) + pow(   pt.Y - e1bot.Y,2)) / d1;
  cInt factor2 = sqrt(pow(   pt.X - e2bot.X,2) + pow(   pt.Y - e2bot.Y,2)) / d2;
  pt.Z = (  (e1bot.Z + (e1top.Z - e1bot.Z) * factor1) * d2
          + (e2bot.Z + (e2top.Z - e2bot.Z) * factor2) * d1
         ) / (d1 + d2);
}

// Both interpolated Z values as 32-bit integers stored in one 64-bit integer.
void zfill_two_interpolate_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  cInt d1 = sqrt(pow(e1top.X - e1bot.X,2) + pow(e1top.Y - e1bot.Y,2));
  cInt d2 = sqrt(pow(e2top.X - e2bot.X,2) + pow(e2top.Y - e2bot.Y,2));
  cInt factor1 = sqrt(pow(   pt.X - e1bot.X,2) + pow(   pt.Y - e1bot.Y,2))
               / d1;
  cInt factor2 = sqrt(pow(   pt.X - e2bot.X,2) + pow(   pt.Y - e2bot.Y,2))
               / d2;
  cUInt hi = (cUInt) ((e1bot.Z + (e1top.Z - e1bot.Z) * factor1) & 0xFFFFFFFF);
  cUInt lo = (cUInt) ((e2bot.Z + (e2top.Z - e2bot.Z) * factor2) & 0xFFFFFFFF);
  hi <<= 32;
  pt.Z = (hi + lo);
}

void zfill_max_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  pt.Z = e1bot.Z > e1top.Z ? e1bot.Z : e1top.Z;
  if (pt.Z < e2bot.Z) { pt.Z = e2bot.Z; }
  if (pt.Z < e2top.Z) { pt.Z = e2top.Z; }
}

void zfill_min_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  pt.Z = e1bot.Z < e1top.Z ? e1bot.Z : e1top.Z;
  if (pt.Z > e2bot.Z) { pt.Z = e2bot.Z; }
  if (pt.Z > e2top.Z) { pt.Z = e2top.Z; }
}

// Maximum Z value from each edge, the two values stored as 32-bit integers
// packed into one 64-bit integer.
//
// If your Z values are indeces into an input point data array, this callback 
// should genrally give you the four relavent indeces just with these two, 
// since the other two will be these minus one.
// (Complex and degenerate polygon and path intersections might break
// that simple mapping. But keep input simple and this should work.)
void zfill_both_max_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  cUInt hi = (cUInt) ((e1bot.Z >= e1top.Z ? e1bot.Z : e1top.Z) & 0xFFFFFFFF);
  cUInt lo = (cUInt) ((e2bot.Z >= e2top.Z ? e2bot.Z : e2top.Z) & 0xFFFFFFFF);
  hi <<= 32;
  pt.Z = (hi + lo);
}

// Minimum Z value from each edge, the two values stored as 32-bit integers
// packed into one 64-bit integer.
//
// Similar to above, but when one of the edge end Zs is zero it can be
// ambigous whether that's the default Z assigned to a previous intersection,
// or an intentional Z from input. (Recommend using 1-based indeces for any
// point data arrays.)
void zfill_both_min_z(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) {
  cUInt hi = (cUInt) ((e1bot.Z <= e1top.Z ? e1bot.Z : e1top.Z) & 0xFFFFFFFF);
  cUInt lo = (cUInt) ((e2bot.Z <= e2top.Z ? e2bot.Z : e2top.Z) & 0xFFFFFFFF);
  hi <<= 32;
  pt.Z = (hi + lo);
}

// store two 32 bit unsigned ints, stored in one 64 bit int
// if Z is used to hold an index into some other data array
// for each point/edge, this lets us return both indeces
// for the intersection point.
// These indeces would have to be limited to 4,294,967,295 - what fits in a U32 -
// and then any point coming back with a Z > than 4,294,967,295 would obviously
// be an intersection point, and the two indeces could be extracted.
// (We're currently using the high bit of the high 32 bits to indicate
// pass-through status for intersections, so the values stored in the 
// high slot can only be up to 31 bit unsigned integers.)
// Should also be able to use this with signed I32 - you would just need
// an extra decoding step to reinterpret the U32 as an I32.

void zfill_both_uint32s(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) { 

  // Always take the low index if either Z holds a high and a low.
  // The lows should always be the ones relevant to this pt.Z.

  // Previously in 6.0.0 beta, this ws chosen for us upstream from here,
  // based on an associated edge's winding number. Now we don't have access to
  // that winding info. But maybe always choosing the "bot" points (higher y val,
  // and probably higher x val to break y tie) will give enough consistency
  // to work out similar functionality here.
  cUInt hi = (cUInt) (e1bot.Z & 0xFFFFFFFF);
  cUInt lo = (cUInt) (e2bot.Z & 0xFFFFFFFF);
  hi <<= 32;

  // gets cast back to signed integer, but bits should stay the same
  pt.Z = (hi + lo);
}

void zfill_both_uint31s_and_flags(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) { 

  // Preserve the Z values of each bottom point,
  // and a one-bit flag indicating whether the 
  // associated top point Z is greater-than-or-equal
  // or less than the bottom Z value.

  // If the Z values are indeces into an array holding input point data, 
  // then the top points here are likely one index up or down from the index
  // for the bottom points. So we only need a hint which way to look to.
  
  // This lets us have 31 bit Z values - up to 2,147,483,647.

  if (e1bot.Z > 0xFFFF || e2bot.Z > 0xFFFF) {
    throw clipperException("Z value outside allowed 31 bit range for z fill callback");
  }

  cUInt hi = (cUInt) (e1bot.Z & 0x7FFFFFFF);
  cUInt lo = (cUInt) (e2bot.Z & 0x7FFFFFFF);
  cUInt hiflag = (cUInt) (e1top.Z >= e1bot.Z ? 1 : 0);
  cUInt loflag = (cUInt) (e2top.Z >= e2bot.Z ? 1 : 0);

  hiflag <<= 63;
  hi     <<= 32;
  loflag <<= 31;

  // gets cast back to signed integer, but bits should stay the same
  pt.Z = (hiflag + hi + loflag + lo);
}

void zfill_second_opinion_vector(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) { 

  // Calculate the intersection of the segments and
  // compare that to the provided intersection point.
  // Store the error as a (delta x, delta y) vector from
  // the Clipperprovided point.
  
  if (e1bot.Z > 0xFFFF || e1top.Z > 0xFFFF || e2bot.Z > 0xFFFF) {
    throw clipperException("Z value outside allowed 21 bit range for z fill callback");
  }

  cUInt hi   = (cUInt) (e1bot.Z & 0x1FFFFF);
  cUInt mid  = (cUInt) (e1top.Z & 0x1FFFFF);
  cUInt lo   = (cUInt) (e2bot.Z & 0x1FFFFF);
  cUInt flag = (cUInt) (e2top.Z >= e2bot.Z ? 1 : 0);

  flag <<= 63;
  hi   <<= 42;
  mid  <<= 21;

  // gets cast back to signed integer, but bits should stay the same
  pt.Z = (flag + hi + mid + lo);
}

void zfill_all_uint16s(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) { 

  // Preserve Z values of all four points, provided those
  // values fit in an unsigned 16 bit integer - up to 65,535.

  if (e1bot.Z > 0xFFFF || e1top.Z > 0xFFFF || e2bot.Z > 0xFFFF || e2top.Z > 0xFFFF) {
    throw clipperException("Z value outside allowed 16 bit range for z fill callback");
  }  

  cUInt hi1 = (cUInt) (e1bot.Z & 0xFFFF);
  cUInt lo1 = (cUInt) (e1top.Z & 0xFFFF);
  cUInt hi2 = (cUInt) (e2bot.Z & 0xFFFF);
  cUInt lo2 = (cUInt) (e2top.Z & 0xFFFF);
  hi1 <<= 48;
  lo1 <<= 32;
  hi2 <<= 16;

  pt.Z = (hi1 + lo1 + hi2 + lo2);
}

// interpret the I64 Z values as 32 bit floats, and store both in one 64 bit int
// May lose precision, but you get two for one.
// Should be useful for low-precision data - 23 bit mantissa, 6 to 9 dec. digits

void zfill_both_float32s(IntPoint& e1bot, IntPoint& e1top, IntPoint& e2bot, IntPoint& e2top, IntPoint& pt) { 

  // simmilar issues as for zfill_both_uint32s() above
  // if we're only saving two, which two? maybe get rid of this one for floats?
  // wasn't documented anyway I don't think
  cUInt hi = (cUInt) (float) e1bot.Z;
  hi <<= 32;
  cUInt lo = (cUInt) (float) e2bot.Z;

  pt.Z = lo + hi;

}

// The edge order for the z1 and z2 values stored above can be made to
// correspond to edge order in the input and result by swaping the hi and low
// values in these two cases:
// (clip type is intersection or difference) xor (point.Y is a local extreme)
// Seems like it would be better to do this at the time the Z fill callback gets
// called, but Angus said it's too complex, considering various overlapping line
// and result simplification steps. But it may be worth while looking into what
// that would take.

void zfill_fix_pair_order(IntPoint& prevpt, IntPoint& thispt, IntPoint& nextpt,
  ClipperLib::ClipType ct, bool is_hole
  ) {

  // precondition: thispt.Z > 0xFFFFFFFF 
  // and thispt.Z < 0x7FFFFFFFFFFFFFFF
  // (top bit signals pre-existing pairs to pass through and not flip)
  if (true) {
      //std::cout << "\n\n\nconsider z pair" << thispt.Z << " : ";
      //std::cout << ((thispt.Z >> 32) & 0x7FFFFFFF) << ", ";
      //std::cout << (thispt.Z & 0x7FFFFFFF) << " at ";
      //std::cout << thispt.X << ", " << thispt.Y << "\n";
      //std::cout << " thisy < prevy : " << thispt.Y << " < " << prevpt.Y << " : ";
      //std::cout << (thispt.Y < prevpt.Y ? "true":"false") << "\n";
      //std::cout << " thisy < nexty : " << thispt.Y << " < " << nextpt.Y << " : ";
      //std::cout << (thispt.Y < nextpt.Y ? "true":"false") << "\n";
      //std::cout << "ct : " << ct << " != to ctXor(" << ctXor << "): ";
      //std::cout << (ct != ctXor ? "true":"false");
      //std::cout << " but == to ctDifference(" << ctDifference << "): ";
      //std::cout << (ct == ctDifference ? "true":"false") <<"\n";

      if (
        (
         // these four cover union, intersection and difference
         ((thispt.Y > prevpt.Y || (thispt.Y == prevpt.Y && thispt.X > prevpt.X)) 
          && (thispt.Y > nextpt.Y ) // || (thispt.Y == nextpt.Y && thispt.X > nextpt.X))
         )
         ||
         ((thispt.Y > prevpt.Y)
          && (thispt.Y > nextpt.Y || (thispt.Y == nextpt.Y && thispt.X > nextpt.X))
          && ct != ctXor
         )
         || 
         ((thispt.Y < prevpt.Y || (thispt.Y == prevpt.Y && thispt.X < prevpt.X))
          && (thispt.Y < nextpt.Y ) // || (thispt.Y == nextpt.Y && thispt.X < nextpt.X))
          )
         || 
         ((thispt.Y < prevpt.Y) 
          && (thispt.Y < nextpt.Y || (thispt.Y == nextpt.Y && thispt.X < nextpt.X))
          && ct != ctXor
          )
         // XOR (for polygons, not referring to the one below) _might_ be similar 
         // but with X playing the staring role.
         // Or it might be more complicated because it's like an intersection and
         // a difference in one operation. 
         // or
         // Might be able to do it by making the sequence of intersections 
         // consistent, sometimes disambiguating by checking neighbor points -  
         // but that wouldn't happen right in here.
         )
         != // xor
         (ct == ctIntersection || ct == ctDifference)       
       ) {    
      //std::cout << "fixpair for " << thispt.Z << ": " << ((thispt.Z >> 32) & 0x7FFFFFFF);
      //std::cout << ", " << (thispt.Z & 0x7FFFFFFF);
      //std::cout << " at " << thispt.X << ", " << thispt.Y << "\n";
      //std::cout << " FLIP";
      thispt.Z = (((thispt.Z & 0x7FFFFFFF) << 32) + ((thispt.Z >> 32) & 0x7FFFFFFF));
    }
    //std::cout << "\n";
  }
}

void zfill_both_uint32s_fix_pairs_polygon(ClipperLib::Path& poly,
  ClipperLib::ClipType ct, bool is_hole = false) {

  unsigned int len = poly.size();

  if (len > 2) {
    if (((cUInt) poly[len - 1].Z) > 0xFFFFFFFF && ((cUInt) poly[len - 1].Z) < 0x8000000000000000) {
      zfill_fix_pair_order(poly[len - 2], poly[len - 1], poly[0], ct, is_hole);
    } //else if (((cUInt) poly[len - 1].Z) >= 0x8000000000000000) {
      //std::cout << "saw pass through: " << ((poly[len - 1].Z >> 32) & 0x7FFFFFFF) << ",";
      //std::cout <<  (poly[len - 1].Z & 0xFFFFFFFF);
      //std::cout << " at " << poly[len - 1].X << "," << poly[len - 1].Y << "," << poly[len - 1].Z << "\n";
    //}
    if (((cUInt) poly[0].Z) > 0xFFFFFFFF       && ((cUInt) poly[0].Z )      < 0x8000000000000000) {
      zfill_fix_pair_order(poly[len - 1], poly[0], poly[1], ct, is_hole);
    } //else if (((cUInt) poly[0].Z) >= 0x8000000000000000) {
      //std::cout << "saw pass through: " << ((poly[0].Z >> 32) & 0x7FFFFFFF) << ",";
      //std::cout <<  (poly[0].Z & 0xFFFFFFFF);
      //std::cout << " at " << poly[0].X << "," << poly[0].Y << "," << poly[0].Z << "\n";
    //}
    for (unsigned int j = 1; j < (len - 1); j++) {
      if (((cUInt) poly[j].Z) > 0xFFFFFFFF     && ((cUInt) poly[j].Z)       < 0x8000000000000000) {
        zfill_fix_pair_order((poly[j - 1]),(poly[j]),(poly[j + 1]),ct,is_hole);
      } //else if (((cUInt) poly[j].Z) >= 0x8000000000000000) {
        //std::cout << "saw pass through: " << ((poly[j].Z >> 32) & 0x7FFFFFFF) << ",";
        //std::cout <<  (poly[j].Z & 0xFFFFFFFF);
        //std::cout << " at " << poly[j].X << "," << poly[j].Y << "," << poly[j].Z << "\n";
      //}
    }
  }
}

void zfill_both_uint32s_fix_pairs_polygons(ClipperLib::Paths& polys,
  ClipperLib::ClipType ct) {

  for (unsigned int i = 0; i < polys.size(); i++) {
    zfill_both_uint32s_fix_pairs_polygon(polys[i], ct, !Orientation(polys[i]));
  }

}

void zfill_both_uint32s_fix_pairs_polynode(ClipperLib::PolyNode& polynode,
  ClipperLib::ClipType ct) {

  zfill_both_uint32s_fix_pairs_polygon(polynode.Contour, ct);
  for (int i = 0; i < polynode.ChildCount(); ++i) {
    zfill_both_uint32s_fix_pairs_polygon(polynode.Childs[i]->Contour, ct, true);
    //Add outer polygons contained by (nested within) holes ...
    for (int j = 0; j < polynode.Childs[i]->ChildCount(); ++j) {
      zfill_both_uint32s_fix_pairs_polynode(*polynode.Childs[i]->Childs[j], ct);
    }
  }

}

void zfill_both_uint32s_fix_pairs_polytree(ClipperLib::PolyTree& polytree,
  ClipperLib::ClipType ct) {

  for (int i = 0; i < polytree.ChildCount(); ++i) {
    zfill_both_uint32s_fix_pairs_polynode(*polytree.Childs[i], ct);
  }

}

void zfill_postprocess(ClipperLib::Paths& p, ClipType clipType, ZFillType zft) {
  if (zft == zftBothUInt32) {
      zfill_both_uint32s_fix_pairs_polygons(p, clipType);
  }
  // debug, print all points in all polygons/paths
  /*
  else {
    for (unsigned int i = 0; i < p.size(); i++) {
      std::cout << "Path[" << i << "]:\n";
      for (unsigned int j = 0; j < p[i].size(); j++) {
        std::cout << "  [" << j << "]: " << p[i][j].X << "," << p[i][j].Y << "," << p[i][j].Z << "\n";
      }
      std::cout << "\n";
    }
  }
  */
}

void zfill_postprocess_pt(ClipperLib::PolyTree& p, ClipType clipType, ZFillType zft) {
    if (zft == zftBothUInt32) {
        zfill_both_uint32s_fix_pairs_polytree(p, clipType);
    }
}

void set_zfill_callback(Clipper& THIS, ZFillType zft) {
    switch (zft) {
        case zftNone : THIS.ZFillFunction(0); break;
        case zftMax  : THIS.ZFillFunction(&zfill_max_z); break;
        case zftMin  : THIS.ZFillFunction(&zfill_min_z);break;
        case zftBothMax  : THIS.ZFillFunction(&zfill_both_max_z); break;
        case zftBothMin  : THIS.ZFillFunction(&zfill_both_min_z);break;
        case zftInterpolateMean : THIS.ZFillFunction(&zfill_average_interpolate_z); break;
        case zftBothUInt32 : THIS.ZFillFunction(&zfill_both_uint32s); break;
        case zftAllUInt16 : THIS.ZFillFunction(&zfill_all_uint16s); break;
        case zftBothUInt31Flags : THIS.ZFillFunction(&zfill_both_uint31s_and_flags); break;
        default      : THIS.ZFillFunction(0);
    }
}

#endif
