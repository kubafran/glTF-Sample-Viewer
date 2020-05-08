// textures.glsl needs to be included

const float M_PI = 3.141592653589793;

in vec3 v_Position;

#ifdef HAS_NORMALS
#ifdef HAS_TANGENTS
in mat3 v_TBN;
#else
in vec3 v_Normal;
#endif
#endif

#ifdef HAS_VERTEX_COLOR_VEC3
in vec3 v_Color;
#endif
#ifdef HAS_VERTEX_COLOR_VEC4
in vec4 v_Color;
#endif

vec4 getVertexColor()
{
   vec4 color = vec4(1.0, 1.0, 1.0, 1.0);

#ifdef HAS_VERTEX_COLOR_VEC3
    color.rgb = v_Color;
#endif
#ifdef HAS_VERTEX_COLOR_VEC4
    color = v_Color;
#endif

   return color;
}

struct NormalInfo {
    mat3 TBNg; // Geometric orthonormal tangent space
    vec3 ng;   // Geometric normal
    vec3 tg;   // Geometric tangent
    vec3 bg;   // Geometric bitangent

    mat3 TBN;  // Pertubed orthonormal tangent space
    vec3 n;    // Pertubed normal
    vec3 t;    // Pertubed tangent
    vec3 b;    // Pertubed bitangent
};

// Get normal, tangent and bitangent vectors.
NormalInfo getNormalInfo(vec3 v)
{
    vec2 UV = getNormalUV();
    vec3 uv_dx = dFdx(vec3(UV, 0.0));
    vec3 uv_dy = dFdy(vec3(UV, 0.0));

    vec3 t_ = (uv_dy.t * dFdx(v_Position) - uv_dx.t * dFdy(v_Position)) /
        (uv_dx.s * uv_dy.t - uv_dy.s * uv_dx.t);

    vec3 n, t, b, ng, tg, bg;
    mat3 TBN, TBNg;

    // Compute geometrical TBN:
    #ifdef HAS_TANGENTS
        // Trivial TBN computation, present as vertex attribute.
        // Normalize eigenvectors as matrix is linearly interpolated.
        tg = normalize(v_TBN[0]);
        bg = normalize(v_TBN[1]);
        ng = normalize(v_TBN[2]);
        TBNg = mat3(tg, bg, ng);
    #else
        // Normals are either present as vertex attributes or approximated.
        #ifdef HAS_NORMALS
            ng = normalize(v_Normal);
        #else
            ng = normalize(cross(dFdx(v_Position), dFdy(v_Position)));
        #endif

        tg = normalize(t_ - ng * dot(ng, t_));
        bg = cross(ng, tg);
        TBNg = mat3(tg, bg, ng);
    #endif

    // For a back-facing surface, the tangential basis vectors are negated.
    float facing = step(0.0, dot(v, ng)) * 2.0 - 1.0;
    TBNg *= facing;
    tg *= facing;
    bg *= facing;
    ng *= facing;

    // Compute pertubed normals:
    #ifdef HAS_NORMAL_MAP
        n = texture(u_NormalSampler, UV).rgb * 2.0 - vec3(1.0);
        n *= vec3(u_NormalScale, u_NormalScale, 1.0);
        n = normalize(TBNg * n);
        t = normalize(tg - n * dot(n, tg));
        b = cross(n, t);
        TBN = mat3(t, b, n);
    #else
        t = tg;
        b = bg;
        n = ng;
    #endif

    NormalInfo info;
    info.tg = tg;
    info.bg = bg;
    info.ng = ng;
    info.TBNg = TBNg;
    info.t = t;
    info.b = b;
    info.n = n;
    info.TBN = TBN;
    return info;
}

float clampedDot(vec3 x, vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
}

float sq(float t)
{
    return t * t;
}

vec2 sq(vec2 t)
{
    return t * t;
}

vec3 sq(vec3 t)
{
    return t * t;
}

vec4 sq(vec4 t)
{
    return t * t;
}

vec3 transmissionAbsorption(vec3 v, vec3 n, float ior, float thickness, vec3 absorptionColor)
{
    vec3 r = refract(-v, n, 1.0 / ior);
    return exp(-absorptionColor * thickness * dot(-n, r));
}
