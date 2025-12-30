package polyline;

using polyline.Extensions;

class Stroke {

    inline static var NUMBER_NONE:Float = -9999999999.0;

    inline static var MATH_TWO_PI:Float = 6.28318530718;

    inline static var MATH_HALF_PI:Float = 1.57079632679;

    inline static var MATH_PI_AND_HALF:Float = 4.71238898038;

    static var miterUtils = new MiterUtils();

    /** The limit before miters turn into bevels. Default 10 */
    public var miterLimit:Float = 10;

    /** The line thickness */
    public var thickness:Float = 1;

    /** The join type, can be `MITER` or `BEVEL`. Default `MITER` */
    public var join:StrokeJoin = MITER;

    /** The cap type. Can be `BUTT` or `SQUARE`. Default `BUTT` */
    public var cap:StrokeCap = BUTT;

    /** Will try to join the first and last points together if they are identical */
    public var canLoop:Bool = false;

    var tmpX:Float = 0;
    
    var tmpY:Float = 0;

    var lineAX:Float = 0;
    
    var lineAY:Float = 0;

    var lineBX:Float = 0;
    
    var lineBY:Float = 0;

    var tangentX:Float = 0;
    
    var tangentY:Float = 0;

    var miterX:Float = 0;
    
    var miterY:Float = 0;

    var capEndX:Float = 0;
    
    var capEndY:Float = 0;

    var _hasNormal:Bool = false;

    var _normalX:Float = 0;

    var _normalY:Float = 0;

    var _lastFlip = -1;

    var _started = false;

    var _points:Array<Float> = null;

    public function new() {

        //

    }

    public function build(points:Array<Float>, vertices:Array<Float>, indices:Array<Int>) {

        // Empty line
        if (vertices.length > 0) {
            #if cpp
            untyped vertices.__SetSize(0);
            #else
            vertices.splice(0, vertices.length);
            #end
        }
        if (indices.length > 0) {
            #if cpp
            untyped indices.__SetSize(0);
            #else
            indices.splice(0, indices.length);
            #end
        }

        if (points.length == 0) {
            return;
        }

        var total = points.length;

        // Clear flags
        _lastFlip = -1;
        _started = false;
        _hasNormal = false;

        // Join each segment
        var i = 2;
        var count = 0;
        var skip = false;
        var lastX = 0.0;
        var lastY = 0.0;
        var curX = 0.0;
        var curY = 0.0;
        var nextX = NUMBER_NONE;
        var nextY = NUMBER_NONE;
        var overlap = false;
        var thickness = 0.0;
        _points = points;
        while (i < total) {
            if (!skip) {
                lastX = points.unsafeGet(i-2);
                lastY = points.unsafeGet(i-1);
                curX = points.unsafeGet(i);
                curY = points.unsafeGet(i+1);
            }
            nextX = NUMBER_NONE;
            nextY = NUMBER_NONE;
            skip = false;
            thickness = mapThickness(curX, curY, i, points);
            if (i < total-2) {
                nextX = points.unsafeGet(i+2);
                nextY = points.unsafeGet(i+3);
                if (curX == nextX && curY == nextY) {
                    skip = true;
                }
                else {
                    // Check if next segment will fold back (angle close to 180 degrees)
                    var dist = distanceToLine(nextX, nextY, curX, curY, lastX, lastY);
                    if (dist < thickness) {
                        var angle = pointsAngle(curX, curY, nextX, nextY, lastX, lastY);
                        if (angle < MATH_HALF_PI || angle > MATH_PI_AND_HALF) {
                            // Mark as fold-back case - don't split the line
                            overlap = true;
                        }
                    }
                }
            }

            if (!skip) {
                var amt = _seg(vertices, indices, count, lastX, lastY, curX, curY, nextX, nextY, thickness * 0.5, overlap);
                count += amt;
            }

            if (nextX == NUMBER_NONE) {
                // We reach end of line
                _lastFlip = -1;
                _started = false;
                _hasNormal = false;
                skip = false;
            }

            // Reset overlap flag for next iteration
            overlap = false;

            i += 2;
        }
        _points = null;
        
        // Is end point the same as start point? If so, compute proper miter join.
        if (canLoop && cap == BUTT) {
            if (points[0] == points[points.length-2] && points[1] == points[points.length-1] && points.length > 6) {

                // Get the second point (first segment direction: points[0,1] -> points[2,3])
                var firstNextX = points[2];
                var firstNextY = points[3];

                // Get the second-to-last point (last segment direction: points[n-4,n-3] -> points[n-2,n-1])
                var lastPrevX = points[points.length - 4];
                var lastPrevY = points[points.length - 3];

                // The join point
                var joinX = points[0];
                var joinY = points[1];

                // Direction of first segment (from join point to next point)
                miterUtils.aX = firstNextX;
                miterUtils.aY = firstNextY;
                miterUtils.bX = joinX;
                miterUtils.bY = joinY;
                miterUtils.direction();
                var lineAX = miterUtils.outX;
                var lineAY = miterUtils.outY;

                // Direction of last segment (from previous point to join point)
                miterUtils.aX = joinX;
                miterUtils.aY = joinY;
                miterUtils.bX = lastPrevX;
                miterUtils.bY = lastPrevY;
                miterUtils.direction();
                var lineBX = miterUtils.outX;
                var lineBY = miterUtils.outY;

                // Compute miter
                miterUtils.aX = lineBX;  // Last segment direction
                miterUtils.aY = lineBY;
                miterUtils.bX = lineAX;  // First segment direction
                miterUtils.bY = lineAY;
                var halfThick = thickness * 0.5;
                var miterLen = miterUtils.computeMiter(halfThick);
                var loopMiterX = miterUtils.miterX;
                var loopMiterY = miterUtils.miterY;

                // Check if miter exceeds limit (fall back to bevel-like behavior)
                var joinBevel = (join == BEVEL);
                if (!joinBevel && join == MITER) {
                    var limit = miterLen / halfThick;
                    if (limit > miterLimit) {
                        joinBevel = true;
                    }
                }

                if (joinBevel) {
                    // For bevel, use normal extrusion (simpler, just use thickness)
                    miterUtils.normal(lineBX, lineBY);
                    loopMiterX = miterUtils.outX;
                    loopMiterY = miterUtils.outY;
                    miterLen = halfThick;
                }

                // Compute the two extruded vertices at the join point
                var extrudeX1 = joinX + (loopMiterX * -miterLen);
                var extrudeY1 = joinY + (loopMiterY * -miterLen);
                var extrudeX2 = joinX + (loopMiterX * miterLen);
                var extrudeY2 = joinY + (loopMiterY * miterLen);

                // Update start vertices (indices 0,1 and 2,3)
                vertices[0] = extrudeX1;
                vertices[1] = extrudeY1;
                vertices[2] = extrudeX2;
                vertices[3] = extrudeY2;

                // Update end vertices (last 4 values)
                vertices[vertices.length - 4] = extrudeX1;
                vertices[vertices.length - 3] = extrudeY1;
                vertices[vertices.length - 2] = extrudeX2;
                vertices[vertices.length - 1] = extrudeY2;
            }
        }

    }

    function mapThickness(pointX:Float, pointY:Float, i:Int, points:Array<Float>) {

        return this.thickness;

    }

    inline function _seg(vertices:Array<Float>, indices:Array<Int>, index:Int, lastX:Float, lastY:Float, curX:Float, curY:Float, nextX:Float, nextY:Float, halfThick:Float, isFoldBack:Bool = false) {

        var count = 0;
        var capSquare = (this.cap == SQUARE);
        var joinBevel = (this.join == BEVEL);

        // Get unit direction of line
        miterUtils.aX = curX;
        miterUtils.aY = curY;
        miterUtils.bX = lastX;
        miterUtils.bY = lastY;
        miterUtils.direction();
        lineAX = miterUtils.outX;
        lineAY = miterUtils.outY;

        // If we don't yet have a normal from previous join,
        // compute based on line start - end
        if (!_hasNormal) {
            miterUtils.normal(lineAX, lineAY);
            _normalX = miterUtils.outX;
            _normalY = miterUtils.outY;
            _hasNormal = true;
        }

        // If we haven't started yet, add the first two points
        if (!_started) {
            _started = true;

            var halfThickStart = mapThickness(_points.unsafeGet(0), _points.unsafeGet(1), 0, _points) * 0.5;

            // If the end cap is type square, we can just push the verts out a bit
            if (capSquare) {
                capEndX = lastX + (lineAX * -halfThickStart);
                capEndY = lastY + (lineAY * -halfThickStart);
                lastX = capEndX;
                lastY = capEndY;
            }

            extrusions(vertices, lastX, lastY, _normalX, _normalY, halfThickStart);
        }

        indices.push(index);
        indices.push(index + 1);
        indices.push(index + 2);

        /*
        // Now determine the type of join with next segment
        - round (TODO)
        - bevel 
        - miter
        - none (i.e. no next segment, use normal)
        */

        if (nextX == NUMBER_NONE) { // No next segment, simple extrusion
            // Now reset normal to finish cap
            miterUtils.normal(lineAX, lineAY);
            _normalX = miterUtils.outX;
            _normalY = miterUtils.outY;
            _hasNormal = true;

            // Push square end cap out a bit
            if (capSquare) {
                capEndX = curX + (lineAX * halfThick);
                capEndY = curY + (lineAY * halfThick);
                curX = capEndX;
                curY = capEndY;
            }

            extrusions(vertices, curX, curY, _normalX, _normalY, halfThick);

            if (_lastFlip == 1) {
                indices.push(index);
                indices.push(index + 2);
                indices.push(index + 3);
            }
            else {
                indices.push(index + 2);
                indices.push(index + 1);
                indices.push(index + 3);
            }

            count += 4;
        } else { // We have a next segment, start with miter
            // Get unit dir of next line
            miterUtils.aX = nextX;
            miterUtils.aY = nextY;
            miterUtils.bX = curX;
            miterUtils.bY = curY;
            miterUtils.direction();
            lineBX = miterUtils.outX;
            lineBY = miterUtils.outY;

            if (isFoldBack) {
                // FOLD-BACK CASE: Angle is close to 180 degrees
                // Create geometry that uses inner corner as pivot, outer corner respects join setting

                // Get normal of current segment
                miterUtils.normal(lineAX, lineAY);
                var normalAX = miterUtils.outX;
                var normalAY = miterUtils.outY;

                // Get normal of next segment
                miterUtils.normal(lineBX, lineBY);
                var normalBX = miterUtils.outX;
                var normalBY = miterUtils.outY;

                // Determine which side is "inner" (the side where the turn is)
                // Use cross product to determine turn direction
                var cross = lineAX * lineBY - lineAY * lineBX;
                var innerFlip = cross > 0 ? 1 : -1;

                // Handle exact 180-degree case (cross product ~= 0)
                if (cross > -0.001 && cross < 0.001) {
                    innerFlip = _lastFlip != 0 ? _lastFlip : 1;
                }

                // Inner side: both segments share the same extruded vertex
                var innerX = curX + normalAX * halfThick * innerFlip;
                var innerY = curY + normalAY * halfThick * innerFlip;

                // Outer side: each segment has its own extruded vertex
                var outerAX = curX + normalAX * halfThick * (-innerFlip);
                var outerAY = curY + normalAY * halfThick * (-innerFlip);
                var outerBX = curX + normalBX * halfThick * (-innerFlip);
                var outerBY = curY + normalBY * halfThick * (-innerFlip);

                // End current segment with: inner corner + outer corner A
                if (innerFlip == 1) {
                    vertices.push(outerAX);
                    vertices.push(outerAY);
                    vertices.push(innerX);
                    vertices.push(innerY);
                } else {
                    vertices.push(innerX);
                    vertices.push(innerY);
                    vertices.push(outerAX);
                    vertices.push(outerAY);
                }

                // Complete the quad for current segment
                if (_lastFlip == 1) {
                    indices.push(index);
                    indices.push(index + 2);
                    indices.push(index + 3);
                } else {
                    indices.push(index + 2);
                    indices.push(index + 1);
                    indices.push(index + 3);
                }

                if (joinBevel) {
                    // BEVEL: Add a flat quad on the outer side
                    // We need 4 vertices for a proper flat fold:
                    // outerA, outerA' (perpendicular), outerB' (perpendicular), outerB

                    // Compute perpendicular points at the fold
                    // Use the bisector direction for the flat edge
                    var bisectX = -(lineAX - lineBX);
                    var bisectY = -(lineAY - lineBY);
                    var bisectLen = Math.sqrt(bisectX * bisectX + bisectY * bisectY);
                    if (bisectLen > 0.001) {
                        bisectX /= bisectLen;
                        bisectY /= bisectLen;
                    } else {
                        // Fallback: use perpendicular to lineA
                        bisectX = -lineAY;
                        bisectY = lineAX;
                    }

                    // Flat edge vertices perpendicular to bisector
                    var flatDist = halfThick;
                    var flatAX = outerAX + bisectX * flatDist * (-innerFlip);
                    var flatAY = outerAY + bisectY * flatDist * (-innerFlip);
                    var flatBX = outerBX + bisectX * flatDist * (-innerFlip);
                    var flatBY = outerBY + bisectY * flatDist * (-innerFlip);

                    // Add vertices for the flat fold (2 triangles forming a quad)
                    vertices.push(flatAX);
                    vertices.push(flatAY);
                    vertices.push(flatBX);
                    vertices.push(flatBY);
                    vertices.push(outerBX);
                    vertices.push(outerBY);

                    // Triangle 1: outerA, flatA, flatB (or inner, depending on flip)
                    if (innerFlip == 1) {
                        // outerA is at index+2, inner at index+3
                        indices.push(index + 2); // outerA
                        indices.push(index + 4); // flatA
                        indices.push(index + 5); // flatB
                        // Triangle 2: outerA, flatB, outerB
                        indices.push(index + 2); // outerA
                        indices.push(index + 5); // flatB
                        indices.push(index + 6); // outerB
                    } else {
                        // inner is at index+2, outerA at index+3
                        indices.push(index + 3); // outerA
                        indices.push(index + 4); // flatA
                        indices.push(index + 5); // flatB
                        // Triangle 2: outerA, flatB, outerB
                        indices.push(index + 3); // outerA
                        indices.push(index + 5); // flatB
                        indices.push(index + 6); // outerB
                    }

                    count += 5; // Added 5 new vertices (inner/outerA pair + flatA + flatB + outerB)
                } else {
                    // MITER: Add fold triangle connecting (inner, outerA, outerB) - pointed shape
                    vertices.push(outerBX);
                    vertices.push(outerBY);

                    // Add the fold triangle
                    if (innerFlip == 1) {
                        // outerA is at index+2, inner at index+3
                        indices.push(index + 3); // inner
                        indices.push(index + 2); // outerA
                        indices.push(index + 4); // outerB
                    } else {
                        // inner is at index+2, outerA at index+3
                        indices.push(index + 2); // inner
                        indices.push(index + 3); // outerA
                        indices.push(index + 4); // outerB
                    }

                    count += 3; // Added 3 new vertices (inner, outerA, outerB)
                }

                // Set up normal for next segment
                _normalX = normalBX;
                _normalY = normalBY;
                _lastFlip = -innerFlip;

            } else {
            // Stores tangent & miter
            miterUtils.tangentX = tangentX;
            miterUtils.tangentY = tangentY;
            miterUtils.miterX = miterX;
            miterUtils.miterY = miterY;
            miterUtils.aX = lineAX;
            miterUtils.aY = lineAY;
            miterUtils.bX = lineBX;
            miterUtils.bY = lineBY;
            var miterLen = miterUtils.computeMiter(halfThick);
            tangentX = miterUtils.tangentX;
            tangentY = miterUtils.tangentY;
            miterX = miterUtils.miterX;
            miterY = miterUtils.miterY;

            // Get orientation
            var flip = ((tangentX * _normalX + tangentY * _normalY) < 0) ? -1 : 1;

            var bevel = joinBevel;
            if (!bevel && join == MITER) {
                var limit = miterLen / (halfThick);
                if (limit > miterLimit) {
                    bevel = true;
                }
            }

            if (bevel) {
                // Next two points in our first segment
                tmpX = curX + (_normalX * -halfThick * flip);
                tmpY = curY + (_normalY * -halfThick * flip);
                vertices.push(tmpX);
                vertices.push(tmpY);
                
                tmpX = curX + (miterX * miterLen * flip);
                tmpY = curY + (miterY * miterLen * flip);
                //trace('tmpY1=$tmpY curY=$curY nextY=$nextY');
                vertices.push(tmpX);
                vertices.push(tmpY);

                if (_lastFlip != -flip) {
                    indices.push(index);
                    indices.push(index + 2);
                    indices.push(index + 3);
                } else {
                    indices.push(index + 2);
                    indices.push(index + 1);
                    indices.push(index + 3);
                }

                // Now add the bevel triangle
                indices.push(index + 2);
                indices.push(index + 3);
                indices.push(index + 4);

                miterUtils.normal(lineBX, lineBY);
                tmpX = miterUtils.outX;
                tmpY = miterUtils.outY;

                // Store normal for next round
                _normalX = tmpX;
                _normalY = tmpY;

                tmpX = curX + (tmpX * -halfThick * flip);
                tmpY = curY + (tmpY * -halfThick * flip);

                vertices.push(tmpX);
                vertices.push(tmpY);

                // The miter is now the normal for our next join
                count += 3;
            } else { // miter
                // Next two points for our miter join
                extrusions(vertices, curX, curY, miterX, miterY, miterLen);
                
                if (_lastFlip == 1) {
                    indices.push(index);
                    indices.push(index + 2);
                    indices.push(index + 3);
                } else {
                    indices.push(index + 2);
                    indices.push(index + 1);
                    indices.push(index + 3);
                }

                flip = -1;

                // The miter is now the normal for our next join
                _normalX = miterX;
                _normalY = miterY;

                count += 2;
            }

            _lastFlip = flip;
            } // end of non-fold-back else branch
        }

        return count;

    }

    inline function extrusions(vertices:Array<Float>, pointX:Float, pointY:Float, normalX:Float, normalY:Float, scale:Float) {

        // Next two points to end our segment
        tmpX = pointX + (normalX * -scale);
        tmpY = pointY + (normalY * -scale);
        vertices.push(tmpX);
        vertices.push(tmpY);

        tmpX = pointX + (normalX * scale);
        tmpY = pointY + (normalY * scale);
        vertices.push(tmpX);
        vertices.push(tmpY);

    }

    inline function pointsAngle(x:Float, y:Float, x0:Float, y0:Float, x1:Float, y1:Float):Float {

        var result = Math.atan2(y1 - y, x1 - x) - Math.atan2(y0 - y, x0 - x);
        while (result < 0) result += MATH_TWO_PI;
        while (result > MATH_TWO_PI) result -= MATH_TWO_PI;
        return result;

    }

    inline function distanceToLine(x:Float, y:Float, x0:Float, y0:Float, x1:Float, y1:Float):Float {

        inline function dot(_x0:Float, _y0:Float, _x1:Float, _y1:Float):Float {
            return _x0 * _x1 + _y0 * _y1;
        }

        var vx = x1 - x0;
        var vy = y1 - y0;
        var wx = x - x0;
        var wy = y - y0;

        var c1 = dot(wx, wy, vx, vy);
        var c2 = dot(vx, vy, vx, vy);
        var b = c1 / c2;

        var pbx = x0 + b * vx;
        var pby = y0 + b * vy;

        var uvx = x - pbx;
        var uvy = y - pby;

        return Math.sqrt(dot(uvx, uvy, uvx, uvy));

    }

}
