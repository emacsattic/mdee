
/**
 * Keep track of the last stack entry.
 */
var gMDE_LastFrame = null;

var gMDE_ScopeProperties = null;

var gMDE_PrettyPrintRequest = null;

function MDE_CallHook() {}

MDE_CallHook.prototype.onCall = function ( frame, type ) {

    gMDE_LastFrame = frame;
    //print( "From CallHook: (frame.scope)" );
    //dumpObject( frame.scope );

    //print( "going to scope out the properties" );

    try { 

        var p = new Object();
        frame.scope.getProperties ( p, {} );

        gMDE_ScopeProperties = new Array( p.length );

        var index = 0;

        //get a copy of the current scope
        for (var i in p.value ) {

            var current = new Object();
            current.name = p.value[i].name.stringValue;
            current.value = p.value[i].value.stringValue;

            gMDE_ScopeProperties[ index ] = current;
                
            ++index;
            
        }

        //if we need to pretty print something
        if ( gMDE_PrettyPrintRequest != null ) {

            var prop = frame.scope.getProperty( gMDE_PrettyPrintRequest );
            gMDE_PrettyPrintRequest = null; //we can reset here because we don't
                                            //need to do any more work

//             if ( prop instanceof String == false ) {
//                 print( "Must specify the name of a variable not an object." );
//                 return;
//             }
            
            //FIXME: make sure prop is valid.
            if ( prop == null ) {
                print( "Property not defined" );
                return;
            }

            pp_jsdIProperty( prop );

            //now this objects subproperties
            var subprops  = new Object();

            //prop = prop.QueryInterface( Components.interfaces.jsdIValue );
            dump( "prop is: " + prop + "\n" );
            dumpObject( prop );
            dump( "prop.value is: " + prop.value + "\n" );
            dumpObject( prop.value );
            prop.value.object.getProperties( subprops, {} );

            //get a copy of the current scope
            for (var i in subprops.value ) {
                pp_jsdIProperty( i );
            }
            
            //FIXME include values includint type information of the jsIProperty
            //here
            
            //FIXME: enumerate properties and functions

        }
        
    } catch ( e ) {
        dump( e );
    }

}

function MDE_ExecutionHook() {}

MDE_ExecutionHook.prototype.onExecute = function ( frame, type, val ) {

    gMDE_LastFrame = frame;

    //print( "From ExecutionHook: (frame.scope)" );
    //dumpObject( frame.scope );

    return Components.interfaces.jsdIExecutionHook.RETURN_CONTINUE;
}

/**
 * Show variables in the current scope
 *
 * @author <a href="mailto:burton@universe">Kevin A. Burton</a>
 */
function scope() {

    //print( "Variables in current scope" );

    for ( var i = 0; i < gMDE_ScopeProperties.length; ++i ) {

        var current = gMDE_ScopeProperties[ i ];
        
        dump( current.name + " = " +
              current.value + "\n" );

    }

}

/**
 * Pretty print a variable via the given name.
 *
 * @author <a href="mailto:burton@universe">Kevin A. Burton</a>
 */
function pp(name) {

    gMDE_PrettyPrintRequest = name;
    
}

/**
 * Given a jsIProperty pretty print it.
 *
 * @author <a href="mailto:burton@universe">Kevin A. Burton</a>
 */
function pp_jsdIProperty( prop ) {

    //dump( prop + "\n" );

    //FIXME: if this is an object how do we determine the object name?

    //FIXME: print prototype information by using the jsPrototype member which
    //is a jsValue
    
    dump( "name: " + prop.name.stringValue + "\n" );
    dump( "\tvalue: " + prop.value.stringValue + "\n" );

    dump( "\ttype: " );

    switch ( prop.value.jsType ) {

        case Components.interfaces.jsdIValue.TYPE_BOOLEAN:
            dump( "boolean" );

        case Components.interfaces.jsdIValue.TYPE_DOUBLE:
            dump( "double" );
            break;

        case Components.interfaces.jsdIValue.TYPE_INT:
            dump( "int" );
            break;

        case Components.interfaces.jsdIValue.TYPE_FUNCTION:
            dump( "function" );
            break;

        case Components.interfaces.jsdIValue.TYPE_NULL:
            dump( "null" );
            break;

        case Components.interfaces.jsdIValue.TYPE_OBJECT:
            dump( "object" );
            break;
    
        case Components.interfaces.jsdIValue.TYPE_STRING:
            dump( "string" );
            break;

        case Components.interfaces.jsdIValue.TYPE_VOID:
            dump( "void" );
            break;

    }

    dump( "\n" );

    dump( "\tnative: " + prop.value.isNative + "\n" );
    dump( "\tprimitive: " + prop.value.isPrimitive + "\n" );

    if ( prop.value.jsPrototype != null ) {
        dump( prop.value.jsPrototype );
        dump( "\tprototype name: " + prop.value.jsPrototype.name.stringValue );
    }
    
}

/**
 * Note that the for/in loop does not enumerate properties in any specific
 * order, and although it enumerates all user-defined properties, it does not
 * enumerate certain predefined properties and methods.
 */
function dumpObject(obj) {

    for(var i in obj) {

        var result = "";
        
        try {
        
            result += i + " = ";

            if ( obj[i] instanceof Function ) {
                result += "Function";
            } else {
                result += obj[ i ];
            }
        } catch ( e ) {
            //dump( e );
        }

        print( result );
        
    }

    if ( obj.prototype != null ) {

        dumpObject( obj.prototype );
        
    }

}

var debugger_service = Components.classes["@mozilla.org/js/jsd/debugger-service;1"].getService();
debugger_service = debugger_service.QueryInterface( Components.interfaces.jsdIDebuggerService );

if ( debugger_service.isOn == false ) {
    print( "Turning debugger on..." );
    debugger_service.on();
    print( "Turning debugger on...done" );
}

var mde_callhook = new MDE_CallHook();
var mde_executionhook = new MDE_ExecutionHook();

//install all the hooks we need.
debugger_service.topLevelHook = mde_callhook;
debugger_service.functionHook = mde_callhook;

debugger_service.breakpointHook = mde_executionhook;
debugger_service.debuggerHook = mde_executionhook;
debugger_service.debugHook = mde_executionhook;
debugger_service.interruptHook = mde_executionhook;
debugger_service.throwHook = mde_executionhook;
