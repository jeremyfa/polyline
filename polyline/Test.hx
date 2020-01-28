package polyline;

class Test {

    public static function main() {

        var points:Array<Float> = [ 25, 25, 15, 60 ];

        var stroke = new polyline.Stroke();
        stroke.thickness = 20;
        stroke.cap = SQUARE;
        stroke.join = BEVEL;
        stroke.miterLimit = 10;

        var vertices:Array<Float> = [];
        var indices:Array<Int> = [];

        stroke.build(points, vertices, indices);

        trace(vertices);
        trace(indices);

    }

}
