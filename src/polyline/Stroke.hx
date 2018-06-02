package polyline;

using polyline.Extensions;

class Stroke {

    inline static var NUMBER_NONE:Float = -9999999999.0;

    static var miterUtils = new MiterUtils();

    /** The limit before miters turn into bevels. Default 10 */
    public var miterLimit:Float = 10;

    /** The line thickness */
    public var thickness:Float = 1;

    /** The join type, can be `MITER` or `BEVEL`. Default `MITER` */
    public var join:StrokeJoin = MITER;

    /** The cap type. Can be `BUTT` or `SQUARE`. Default `BUTT` */
    public var cap:StrokeCap = BUTT;

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

    public function new() {

        //

    } //new

    public function build(points:Array<Float>, vertices:Array<Float>, indices:Array<Float>) {

        // Empty line
        if (vertices.length > 0) {
            vertices.splice(0, vertices.length);
        }
        if (indices.length > 0) {
            indices.splice(0, indices.length);
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
        while (i < total) {
            var lastX = points.unsafeGet(i-2);
            var lastY = points.unsafeGet(i-1);
            var curX = points.unsafeGet(i);
            var curY = points.unsafeGet(i+1);
            var nextX = NUMBER_NONE;
            var nextY = NUMBER_NONE;
            if (i < total-2) {
                nextX = points.unsafeGet(i+2);
                nextY = points.unsafeGet(i+3);
            }
            var thickness = mapThickness(curX, curY, i, points);
            var amt = _seg(vertices, indices, count, lastX, lastY, curX, curY, nextX, nextY, thickness * 0.5);

            count += amt;
            i += 2;
        }

    } //build

    function mapThickness(pointX:Float, pointY:Float, i:Int, points:Array<Float>) {

        return this.thickness;

    } //mapThickness

    inline function _seg(vertices:Array<Float>, indices:Array<Float>, index:Int, lastX:Float, lastY:Float, curX:Float, curY:Float, nextX:Float, nextY:Float, halfThick:Float) {

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

            // If the end cap is type square, we can just push the verts out a bit
            if (capSquare) {
                capEndX = lastX + (lineAX * -halfThick);
                capEndY = lastY + (lineAY * -halfThick);
                lastX = capEndX;
                lastY = capEndY;
            }

            extrusions(vertices, lastX, lastY, _normalX, _normalY, halfThick);
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

            count += 2;
        } else { // We have a next segment, start with miter
            // Get unit dir of next line
            miterUtils.aX = nextX;
            miterUtils.aY = nextY;
            miterUtils.bX = curX;
            miterUtils.bY = curY;
            miterUtils.direction();
            lineBX = miterUtils.outX;
            lineBY = miterUtils.outY;

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
        }

        return count;

    } //_seg

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

    } //extrusions

} //Stroke
