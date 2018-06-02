# polyline

![](https://camo.githubusercontent.com/f78843ec2d10026f91eaf3f51d4a15426141cbb5/687474703a2f2f692e696d6775722e636f6d2f4c474b73546a322e706e67)

An utility to create polylines written in Haxe (ported from https://github.com/mattdesl/extrude-polyline ; preview image from original library)

### Example

```haxe
var points:Array<Float> = [
    25, 25,
    15, 60
];

var stroke = new polyline.Stroke();
stroke.thickness = 5;
stroke.cap = BUTT;
stroke.join = MITER;
stroke.miterLimit = 10;

var vertices:Array<Float> = [];
var indices:Array<Int> = [];

stroke.build(points, vertices, indices);

trace('vertices: $vertices');
trace('indices: $indices');
```
