const JNI_VERSION_1_1 =  convert(Cint, 0x00010001)
const JNI_VERSION_1_2 =  convert(Cint, 0x00010002)
const JNI_VERSION_1_4 =  convert(Cint, 0x00010004)
const JNI_VERSION_1_6 =  convert(Cint, 0x00010006)
const JNI_VERSION_1_8 =  convert(Cint, 0x00010008)

const JNI_TRUE = convert(Cchar, 1)
const JNI_FALSE = convert(Cchar, 0)

# Return Values
const JNI_OK           = convert(Cint, 0)               #/* success */
const JNI_ERR          = convert(Cint, -1)              #/* unknown error */
const JNI_EDETACHED    = convert(Cint, -2)              #/* thread detached from the VM */
const JNI_EVERSION     = convert(Cint, -3)              #/* JNI version error */
const JNI_ENOMEM       = convert(Cint, -4)              #/* not enough memory */
const JNI_EEXIST       = convert(Cint, -5)              #/* VM already created */
const JNI_EINVAL       = convert(Cint, -6)              #/* invalid arguments */

function javahome_winreg()
    try
        keypath = "SOFTWARE\\JavaSoft\\Java Runtime Environment"
        value = querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "CurrentVersion")
        keypath *= "\\"*value
        return querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "JavaHome")
    catch
        try
            keypath = "SOFTWARE\\JavaSoft\\Java Development Kit"
            value = querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "CurrentVersion")
            keypath *= "\\"*value
            return querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "JavaHome")
        catch
            error("Cannot find an installation of Java in the Windows Registry.  Please install Java from https://java.com/en/download/manual.jsp and subsequently reload JavaCall.")
        end
    end
end

@static is_unix() ? (global const libname = "libjvm") : (global const libname = "jvm")

function findjvm()
    javahomes = Any[]
    libpaths = Any[]

    if haskey(ENV,"JAVA_HOME")
        push!(javahomes,ENV["JAVA_HOME"])
    else
        @static is_windows() ? ENV["JAVA_HOME"] = javahome_winreg() : nothing
        @static is_windows() ? push!(javahomes, ENV["JAVA_HOME"]) : nothing
    end

    if isfile("/usr/libexec/java_home")
        push!(javahomes,chomp(readstring(`/usr/libexec/java_home`)))
    end

    if isdir("/usr/lib/jvm/default-java/")
        push!(javahomes, "/usr/lib/jvm/default-java/")
    end

    push!(libpaths,pwd())
    for n in javahomes
        @static if is_windows()
            push!(libpaths, joinpath(n, "bin", "server"))
            push!(libpaths, joinpath(n, "jre", "bin", "server"))
            push!(libpaths, joinpath(n, "bin", "client"))
        end
        @static if is_linux()
             if Sys.WORD_SIZE==64
                push!(libpaths, joinpath(n, "jre", "lib", "amd64", "server"))
			elseif Sys.WORD_SIZE==32
                push!(libpaths, joinpath(n, "jre", "lib", "i386", "server"))
             end
         end
        push!(libpaths, joinpath(n, "jre", "lib", "server"))
        push!(libpaths, joinpath(n, "lib", "server"))
    end

    ext = @static is_windows()?"dll":(@static is_apple()?"dylib":"so")
    ext = "."*ext

    try
        for n in libpaths
            libpath = joinpath(n,libname*ext);
            if isfile(libpath)
                if is_windows()
                    bindir = dirname(dirname(libpath))
                    m = filter(x -> ismatch(r"msvcr(?:.*).dll",x), readdir(bindir))
                    Libdl.dlopen(joinpath(bindir,m[1]))
                end
                global libjvm = Libdl.dlopen(libpath)
                println("Loaded $libpath")
                return
            end
        end
    end

    errorMsg =
        [
         "Cannot find java library $libname$ext\n",
         "Search Path:"
         ];
    for path in libpaths
        push!(errorMsg,"\n   $path")
    end
    error(reduce(*,errorMsg));
end





immutable JavaVMOption
    optionString::Ptr{UInt8}
    extraInfo::Ptr{Void}
end

immutable JavaVMInitArgs
    version::Cint
    nOptions::Cint
    options::Ptr{JavaVMOption}
    ignoreUnrecognized::Cchar
end


@static is_unix() ? (const sep = ":") : nothing
@static is_windows() ? (const sep = ";") : nothing
cp=OrderedSet{String}()
opts=OrderedSet{String}()

function addClassPath(s::String)
    if isloaded()
        warn("JVM already initialised. This call has no effect")
        return
    end
    if s==""; return; end
    if endswith(s, "/*") && isdir(s[1:end-2])
        for x in s[1:end-1] .* readdir(s[1:end-2])
            if endswith(x, ".jar")
                push!(cp, x)
            end
        end
        return
    end
    push!(cp, s)
    return
end

addOpts(s::String) = isloaded()?warn("JVM already initialised. This call has no effect"): push!(opts, s)

function init()
    if isempty(cp)
        init(opts)
    else
        ccp = collect(cp)
        init(vcat(collect(opts), reduce((x,y)->string(x,sep,y),"-Djava.class.path=$(ccp[1])",ccp[2:end])))
    end
end

isloaded() = isdefined(JavaCall, :jnifunc) && isdefined(JavaCall, :penv) && penv != C_NULL

assertloaded() = isloaded()?nothing:error("JVM not initialised. Please run init()")
assertnotloaded() = isloaded()?error("JVM already initialised"):nothing

# Pointer to pointer to pointer to pointer alert! Hurrah for unsafe load
function init(opts)
    assertnotloaded()
    opt = [JavaVMOption(pointer(x), C_NULL) for x in opts]
    ppjvm=Array{Ptr{JavaVM}}(1)
    ppenv=Array{Ptr{JNIEnv}}(1)
    vm_args = JavaVMInitArgs(JNI_VERSION_1_6, convert(Cint, length(opts)), convert(Ptr{JavaVMOption}, pointer(opt)), JNI_TRUE)

    res = ccall(create, Cint, (Ptr{Ptr{JavaVM}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), ppjvm, ppenv, &vm_args)
    if res < 0; error("Unable to initialise Java VM: $(res)"); end
    global penv = ppenv[1]
    global pjvm = ppjvm[1]
    jnienv=unsafe_load(penv)
    jvm = unsafe_load(pjvm)
    global jvmfunc = unsafe_load(jvm.JNIInvokeInterface_)
    global jnifunc = unsafe_load(jnienv.JNINativeInterface_) #The JNI Function table
    return
end

function destroy()
    if (!isdefined(JavaCall, :penv) || penv == C_NULL) ; error("Called destroy without initialising Java VM"); end
    res = ccall(jvmfunc.DestroyJavaVM, Cint, (Ptr{Void},), pjvm)
    if res < 0; error("Unable to destroy Java VM"); end
    global penv=C_NULL; global pjvm=C_NULL;
end
