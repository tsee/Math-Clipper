#ifndef clipper_zfill_h_
#define clipper_zfill_h_

#define ZMARK -1;
//#include <iostream>

void zfill_mark(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = ZMARK;
}

void zfill_mean(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = (z1 + z2) / 2;
}

void zfill_greater(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z1 > z2 ? z1 : z2;
}

void zfill_lesser(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z1 < z2 ? z1 : z2;
}

void zfill_first(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z1;
}

void zfill_second(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z2;
}

// store two 32 bit unsigned ints, stored in one 64 bit int
// if Z is used to hold an index into some other data array
// for each point/edge, this lets us return both indeces
// for the intersection point.
// These indeces would have to be limited to 4,294,967,295 - what fits in a U32 -
// and then any point coming back with a Z > than 4,294,967,295 would obviously
// be an intersection point, and the two indeces could be extracted.
// (We're currently using the high bit of the high 32 bits to indicate
// "pass-through" status for intersections, so the values stored in the 
// high slot can only be up to 31 bit unsigned integers.)
// Should also be able to use this with signed I32 - you would just need
// an extra decoding step to reinterpret the U32 as an I32.

void zfill_both_uint32s(long64 z1, long64 z2, IntPoint& pt) { 

  // Always take the low index if either Z holds a high and a low.
  // The lows should always be the ones relevant to this pt.Z.

  cUInt hi = (cUInt) (z1 & 0xFFFFFFFF);
  cUInt lo = (cUInt) (z2 & 0xFFFFFFFF);
  hi <<= 32;

  // gets cast back to signed integer, but bits should stay the same
  pt.Z = (hi + lo);
  //std::cout << " int happens at [" << (cInt) pt.X << ", " << (cInt) pt.Y << "] given Z: " << (hi >> 32) << "," << lo << " from " << z1 << " and " << z2 << "\n";
}

// The edge order for the z1 and z2 values stored above can be made to
// correspond to edge order in the input and result by swaping the hi and low
// values in these two cases:
// (clip type is intersection or difference) xor (point.Y is a local extreme)
// Seems like it would be better to do this at the time the Z fill coallback gets
// called, but Angus said it's too complex, considering varius overlapping line
// and result simplification steps. But it may be worth while looking into what
// that would take.

void zfill_fix_pair_order(IntPoint& prevpt, IntPoint& thispt, IntPoint& nextpt,
  ClipperLib::ClipType ct, bool is_hole
  ) {

  // precondition: thispt.Z > 0xFFFFFFFF 
  // and thispt.Z < 0x7FFFFFFFFFFFFFFF
  // (top bit signals pre-existing pairs to pass through and not flip)
  if (true) {
      //std::cout << "consider z pair" << thispt.Z << " : ";
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

void zfill_both_uint32s_fix_pairs_polygon(ClipperLib::Polygon& poly,
  ClipperLib::ClipType ct, bool is_hole = false) {

  unsigned int len = poly.size();

  if (len > 2) {
    if (((cUInt) poly[len - 1].Z) > 0xFFFFFFFF && ((cUInt) poly[len - 1].Z) < 0x8000000000000000) {
      zfill_fix_pair_order(poly[len - 2], poly[len - 1], poly[0], ct, is_hole);
    } //else if (((cUInt) poly[len - 1].Z) >= 0x8000000000000000) {
      //std::cout << "saw pass through: " << ((poly[len - 1].Z >> 32) & 0x7FFFFFFF) << ",";
      //std::cout <<  (poly[len - 1].Z & 0xFFFFFFFF);
      //std::cout << " at " << poly[len - 1].X << "," << poly[len - 1].Y << "\n";
    //}
    if (((cUInt) poly[0].Z) > 0xFFFFFFFF       && ((cUInt) poly[0].Z )      < 0x8000000000000000) {
      zfill_fix_pair_order(poly[len - 1], poly[0], poly[1], ct, is_hole);
    } //else if (((cUInt) poly[0].Z) >= 0x8000000000000000) {
      //std::cout << "saw pass through: " << ((poly[0].Z >> 32) & 0x7FFFFFFF) << ",";
      //std::cout <<  (poly[0].Z & 0xFFFFFFFF);
      //std::cout << " at " << poly[0].X << "," << poly[0].Y << "\n";
    //}
    for (unsigned int j = 1; j < (len - 1); j++) {
      if (((cUInt) poly[j].Z) > 0xFFFFFFFF     && ((cUInt) poly[j].Z)       < 0x8000000000000000) {
        zfill_fix_pair_order((poly[j - 1]),(poly[j]),(poly[j + 1]),ct,is_hole);
      } //else if (((cUInt) poly[j].Z) >= 0x8000000000000000) {
        //std::cout << "saw pass through: " << ((poly[j].Z >> 32) & 0x7FFFFFFF) << ",";
        //std::cout <<  (poly[j].Z & 0xFFFFFFFF);
        //std::cout << " at " << poly[j].X << "," << poly[j].Y << "\n";
      //}
    }
  }
}

void zfill_both_uint32s_fix_pairs_polygons(ClipperLib::Polygons& polys,
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

// interpret the I64 Z values as 32 bit floats, and store both in one 64 bit int
// May lose precision, but you get two for one.
// Should be useful for low-precision data - 23 bit mantissa, 6 to 9 dec. digits

void zfill_both_float32s(long64 z1, long64 z2, IntPoint& pt) { 

  cUInt hi = (cUInt) (float) z1;
  hi <<= 32;
  cUInt lo = (cUInt) (float) z2;

  // back to signed interger, because that's what Clipper expects
  pt.Z = (long64) lo + hi;

}


void zfill_postprocess(ClipperLib::Polygons& p, ClipType clipType, ZFillType zft) {
    if (zft == zftBothUInt32) {
        zfill_both_uint32s_fix_pairs_polygons(p, clipType);
    }
}

void zfill_postprocess_pt(ClipperLib::PolyTree& p, ClipType clipType, ZFillType zft) {
    if (zft == zftBothUInt32) {
        zfill_both_uint32s_fix_pairs_polytree(p, clipType);
    }
}

void set_zfill_callback(Clipper& THIS, ZFillType zft) {
    switch (zft) {
        case zftNone : THIS.ZFillFunction(0); break;
        case zftMax  : THIS.ZFillFunction(&zfill_greater); break;
        case zftMin  : THIS.ZFillFunction(&zfill_lesser);break;
        case zftMean : THIS.ZFillFunction(&zfill_mean); break;
        case zftBothUInt32 : THIS.ZFillFunction(&zfill_both_uint32s); break;
        default      : THIS.ZFillFunction(0);
    }
}

#endif
