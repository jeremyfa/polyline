package polyline;

class Extensions {

/// Array extensions

    #if !debug inline #end public static function unsafeGet<T>(array:Array<T>, index:Int):T {
#if debug
        if (index < 0 || index >= array.length) throw 'Invalid unsafeGet: index=$index length=${array.length}';
#end
#if cpp
        #if app_cpp_nativearray_unsafe
        return cpp.NativeArray.unsafeGet(array, index);
        #else
        return untyped array.__unsafe_get(index);
        #end
#elseif cs
        return cast untyped __cs__('{0}.__a[{1}]', array, index);
#else
        return array[index];
#end
    }

    #if !debug inline #end public static function unsafeSet<T>(array:Array<T>, index:Int, value:T):Void {
#if debug
        if (index < 0 || index >= array.length) throw 'Invalid unsafeSet: index=$index length=${array.length}';
#end
#if cpp
        #if app_cpp_nativearray_unsafe
        cpp.NativeArray.unsafeSet(array, index, value);
        #else
        untyped array.__unsafe_set(index, value);
        #end
#elseif cs
        return cast untyped __cs__('{0}.__a[{1}] = {2}', array, index, value);
#else
        array[index] = value;
#end
    }

}
