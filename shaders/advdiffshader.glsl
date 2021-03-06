# version 330 core

out vec4 x_out; // (v_x, v_y, pressure, unused)
in vec2 texcoord;

uniform sampler2D x_prev; // v_x, v_y, p, divergence
uniform sampler2D v_source; // velocity source

uniform float rho;
uniform float mu;
uniform float dl;
uniform float di;
uniform float dt;

uniform float use_source;
uniform vec2 source_dir;


void main()
{
    vec4 field = texture(x_prev, texcoord);
    vec4 field_N = texture(x_prev, texcoord + vec2(0.0, di)); // y goes up the screen inverse texco/pos
    vec4 field_S = texture(x_prev, texcoord + vec2(0.0, -di));
    vec4 field_E = texture(x_prev, texcoord + vec2(di, 0.0));
    vec4 field_W = texture(x_prev, texcoord + vec2(-di, 0.0));

    float vx = field.r;
    float vy = field.g;

    // Upwinding
    float vxdvx_dx = (vx > 0) ? vx*(field.r - field_W.r)/dl : vx*(field_E.r - field.r)/dl;
    float vydvx_dy = (vy > 0) ? vy*(field.r - field_S.r)/dl : vy*(field_N.r - field.r)/dl;

    float vxdvy_dx = (vx > 0) ? vx*(field.g - field_W.g)/dl : vx*(field_E.g - field.g)/dl;
    float vydvy_dy = (vy > 0) ? vy*(field.g - field_S.g)/dl : vy*(field_N.g - field.g)/dl;

    float dvx_dt_adv = -vxdvx_dx - vydvx_dy ;
    float dvy_dt_adv = -vxdvy_dx - vydvy_dy ;

    // Apply advection
    float out_vx = vx + dt * dvx_dt_adv;
    float out_vy = vy + dt * dvy_dt_adv;

//    // working serial implementation
//    // Advection (central difference, consider upwinding)
//            float dvx_dt_adv = -m_previous->v_x(i,j) * d_dx(m_previous->v_x, i, j)
//                               -m_previous->v_y(i,j) * d_dy(m_previous->v_x, i, j);
//
//            m_next->v_x(i,j) = m_previous->v_x(i,j) + m_simParams.dt * dvx_dt_adv;
//
//            float dvy_dt_adv = -m_previous->v_x(i,j) * d_dx(m_previous->v_y, i, j)
//                               -m_previous->v_y(i,j) * d_dy(m_previous->v_y, i, j);
//
//            m_next->v_y(i,j) = m_previous->v_y(i,j) + m_simParams.dt * dvy_dt_adv;

    // Calculate second derivatives
    float inv_dlsq = 1.f/(dl*dl);
    vec4 d2field_dx2 = (field_E - 2*field + field_W) * inv_dlsq;
    vec4 d2field_dy2 = (field_N - 2*field + field_S) * inv_dlsq;

    float d2vx_dx2 = d2field_dx2.r;
    float d2vx_dy2 = d2field_dy2.r;

    float d2vy_dx2 = d2field_dx2.g;
    float d2vy_dy2 = d2field_dy2.g;

    // Apply diffusion
    float nu = mu/rho;
    float dvx_dt_diff = nu * (d2vx_dx2 + d2vx_dy2);
    float dvy_dt_diff = nu * (d2vy_dx2 + d2vy_dy2);

    out_vx = out_vx + dt * dvx_dt_diff;
    out_vy = out_vy + dt * dvy_dt_diff;

//    // Serial working implementation
//            //Diffusion (consider implicit/stable)
//            float dvx_dt_diff = m_params.viscosity/m_params.density *
//                              ( d2_dx2(m_previous->v_x, i, j)
//                              + d2_dy2(m_previous->v_x, i, j) );
//
//            m_next->v_x(i,j) = m_next->v_x(i,j) + m_simParams.dt * dvx_dt_diff;
//
//            float dvy_dt_diff = m_params.viscosity/m_params.density *
//                              ( d2_dx2(m_previous->v_y, i, j)
//                              + d2_dy2(m_previous->v_y, i, j) );
//
//            m_next->v_y(i,j) = m_next->v_y(i,j) + m_simParams.dt * dvy_dt_diff;

    // apply source
//    vec4 vs_term = texture(v_source, texcoord);
//    out_vx = (vs_term.b > 0.1) ? out_vx + dt*(vs_term.r - out_vx) : out_vx;
//    out_vy = (vs_term.b > 0.1) ? out_vy + dt*(vs_term.g - out_vy) : out_vy;

//        // apply source
    if (use_source > 0.01)
    {
        vec4 vs_term = texture(v_source, texcoord);
        vs_term.xy = source_dir;
        out_vx = (1.f-vs_term.b)*out_vx + (vs_term.b)*(out_vx + dt*(vs_term.r - out_vx));
        out_vy = (1.f-vs_term.a)*out_vy + (vs_term.a)*(out_vy + dt*(vs_term.g - out_vy));
    }

    // apply constant force
    //float coriolis = 0.001; // acceleration m/s2
    //out_vx = out_vx + dt*coriolis;

    // introduce terrain drag...

    vec4 val = vec4(out_vx, out_vy, field.p, field.a);

    x_out = val;
}
