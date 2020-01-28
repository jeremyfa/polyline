package polyline;

class MiterUtils {

    public var tangentX:Float = 0;

    public var tangentY:Float = 0;

    public var miterX:Float = 0;

    public var miterY:Float = 0;

    public var aX:Float = 0;

    public var aY:Float = 0;

    public var bX:Float = 0;

    public var bY:Float = 0;

    public var outX:Float = 0;

    public var outY:Float = 0;

    var tmpX:Float = 0;

    var tmpY:Float = 0;

    public function new() {}

    inline public function computeMiter(halfThick:Float) {

        // Get tangent line
        tangentX = aX + bX;
        tangentY = aY + bY;

        // Get miter as a unit vector
        miterX = -tangentY;
        miterY = tangentX;
        tmpX = -aY;
        tmpY = aX;

        // Get the necessary length of our miter
        return halfThick / (miterX * tmpX + miterY * tmpY);

    }

    inline public function normal(dirX:Float, dirY:Float) {

        // Get perpendicular
        outX = -dirY;
        outY = dirX;

    }

    inline public function direction() {

        // Get unit dir of two lines
        outX = aX - bX;
        outY = aY - bY;
        var len = outX * outX + outY * outY;
        if (len > 0) {
            len = 1.0 / Math.sqrt(len);
            outX = outX * len;
            outY = outY * len;
        }

    }

}
