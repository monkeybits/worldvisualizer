# version 330 core

// x_t_k is the field variables (v_x, v_y, pressure, rho)

out vec4 x_t1k1; // next timestep, next jacobi iteration solution
in vec2 texcoord;

uniform sampler2D x_t1k0; // previous fixed point jacobi iteration result of next timestep solution
uniform sampler2D x_t0kN; // previous timestep accepted solution
uniform sampler2D source;

uniform float mu;
uniform float dl;
uniform float di;
uniform float dt;

void main()
{
//    vec4 prev_field = texture(x_t0kN, texcoord);
    vec4 field = texture(x_t1k0, texcoord);
    vec4 field_N = texture(x_t1k0, texcoord + vec2(0.0, di)); // y goes up the screen inverse texco/pos
    vec4 field_S = texture(x_t1k0, texcoord + vec2(0.0, -di));
    vec4 field_E = texture(x_t1k0, texcoord + vec2(di, 0.0));
    vec4 field_W = texture(x_t1k0, texcoord + vec2(-di, 0.0));

    // Calculate first derivatives
    float inv_2dl = 1.f/(2.0*dl);
    vec4 dfield_dx = (field_E - field_W) * inv_2dl;
    vec4 dfield_dy = (field_N - field_S) * inv_2dl;
//
//    float dvx_dx = dfield_dx.r;
//    float dvy_dy = dfield_dy.g;
//
//    // source is divergence:
//    // dvx_dx + dvy_dy = div_source(x, y);
//
//    //vec4 s_term = texture(div_source, texcoord);
//
//    //float div = dvx_dx + dvy_dy - max(s_term.r/50000.f, 0.0);
//
//    float div = dvx_dx + dvy_dy;
//
//    float next_p = (field_W.b + field_E.b + field_N.b + field_S.b - dl*dl*div*rho/dl) / 4.f;
//
//    x_out = vec4(field.rg, next_p, field.a);

    // output
    x_t1k1 = field;

    //x_out = vec4(s_term.r < 1, s_term.r < 1, s_term.r < 1, 1.0);


// serial working implementation
//                m_next->p(i,j) = ( m_next->p(i-1,j) + m_next->p(i+1,j)
//                                 + m_next->p(i,j-1) + m_next->p(i,j+1)
//                                 - m_simParams.dl*m_simParams.dl*m_calc.div(i,j)*m_params.density/m_simParams.dl ) / 4.f;
}
