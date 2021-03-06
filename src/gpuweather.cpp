#include "gpuweather.h"

gpuWeather::gpuWeather(unsigned int dim, float* height_data, unsigned int x_res, unsigned int y_res) :
    m_result(ClosedMap<float>(log2(dim))),
    m_params(
                 {
                    ClosedMap<float>(log2(dim)), //S_vx
                    ClosedMap<float>(log2(dim)), //S_vy
                    15, //density
                    0.1 //viscosity
                 }
            ),
    m_simParams(
                 {
                     0.3, //dl
                 }
            ),
    m_timeStep(0),
    m_time(0.0)
{
    //ctor

    unsigned int n_valsPerCell = 4;

    float* source = new float [n_valsPerCell*dim*dim];
    float* vx_vy_p_t = new float [n_valsPerCell*dim*dim];
    //float* transp = new float [n_valsPerCell*dim*dim]; // transported quantities

    int num_sources = 10;
    int num_clouds = 10;

    int num_pts = num_sources+num_clouds;
    float rand_x[num_pts];
    float rand_y[num_pts];
    float rand_xs[num_pts];
    float rand_ys[num_pts];

    for (int i = 0; i<num_pts; i++)
    {
        rand_x[i] = (float)(rand()%1000)/1000.f;
        rand_y[i] = (float)(rand()%1000)/1000.f;
        rand_xs[i] = 0.25*(float)(rand()%1000)/1000.f;
        rand_ys[i] = 0.25*(float)(rand()%1000)/1000.f;
    }

    for (int i = 0; i<dim; i++)
    {
        for (int j = 0; j<dim; j++)
        {
            float* s_node = &source[n_valsPerCell*i*dim+n_valsPerCell*j];
            s_node[0] = 0.0; s_node[1] = 0.0; s_node[2] = 0.0; s_node[3] = 0.0;

            float* vp_node = &vx_vy_p_t[n_valsPerCell*i*dim+n_valsPerCell*j];
            vp_node[0] = 0.0; vp_node[1] = 0.0; vp_node[2] = 1.0; vp_node[3] = 0.0; // set pressure to one

            //float* tr_node = &transp[n_valsPerCell*i*dim+n_valsPerCell*j];
            //tr_node[0] = 0.0; tr_node[1] = 0.0; tr_node[2] = 0.0; tr_node[3] = 0.0; // Transported quantities

//            if (i/(float)(dim) > 0.0 && i/(float)(dim) < 0.2 &&
//                j/(float)(dim) > 0.2 && j/(float)(dim) < 0.4)
//            {
//                //s_node[0] = 1.f;
//                //s_node[1] = 1.f;
//
//                vp_node[0] = 3.f;
//                vp_node[1] = 3.f;
//                //
//                vp_node[3] = 1.f; // set transported quantity 1
//
//                //tr_node[0] = 1.f;
//                //tr_node[1] = 1.f;
//            }

            //vp_node[3] = height_data[((4*i)%(dim/4))*dim+((4*j)%(dim/4))] > 0;

            //vp_node[3] = height_data[(i/2)*dim+j/2] > 0;

            // r: s_vx, g: s_vy, b: w_s_vx, a: w_s_vy
            float source_vals1[4] = {1.f, -0.3f, 1.f, 1.f};
//
            valBox(0.2, 0.3, 0.6, 0.7,
                   i, j, dim,
                   s_node, source_vals1);
//
//            // r: s_vx, g: s_vy, b: w_s_vx, a: w_s_vy
//            float source_vals2[4] = {-3.f, 1.f, 1.f, 1.f};
////
//            valBox(0.7, 0.8, 0.3, 0.4,
//                   i, j, dim,
//                   s_node, source_vals2);


//            float cloud_vals[4] = {0.0, 0.0, 1.0, 1.0};
//            for (int k = 0; k<num_pts; k++)
//            {
//                valBox(rand_x[k], rand_x[k]+rand_xs[k], rand_y[k], rand_y[k]+rand_ys[k],
//                       i, j, dim,
//                       vp_node, cloud_vals);
//            }


        }
    }

    // initialize and connect the shaders
    m_advdiffShader.init(dim, vx_vy_p_t, source, // Create the source texture
                         m_params.density, // use as uniform
                         m_params.viscosity,  // use as uniform
                         m_simParams.dl);  // use as uniform
//
    m_pressShader.init(dim, m_advdiffShader.getXdashTextureID(),  // use as input texture
                       height_data,
                       m_params.density, // use as uniform
                       m_params.viscosity,  // use as uniform
                       m_simParams.dl);  // use as uniform
//
    m_velCorrShader.init(dim, m_advdiffShader.getInitCondTextureID(),
                         height_data,
                         m_params.density, // use as uniform
                         m_params.viscosity, // use as uniform
                         m_simParams.dl); // use as uniform
//
    m_fluidDispShader.init(dim, m_simParams.dl);

    delete [] source;
    delete [] vx_vy_p_t;
    //delete [] transp;

    m_dim = dim;
    m_xres = x_res;
    m_yres = y_res;


}

void gpuWeather::valBox(float x_min, float x_max, float y_min, float y_max,
                        int i, int j, int dim,
                        float* field, float val_in_box[4])
{
    if (i/(float)(dim) > y_min && i/(float)(dim) < y_max &&
        j/(float)(dim) > x_min && j/(float)(dim) < x_max)
    {
        field[0] = val_in_box[0];
        field[1] = val_in_box[1];
        field[2] = val_in_box[2];
        field[3] = val_in_box[3];
    }
}


void gpuWeather::step(float dt)
{
    glViewport(0, 0, m_dim, m_dim);
    // switch to adv/diffusion shader
    m_advdiffShader.step(dt, false);
    GLuint tex_for_next = m_pressShader.step(dt, 10, false); // iterations
    GLuint solution_tex = m_velCorrShader.step(dt, tex_for_next, false);

    glViewport(0, 0, m_xres, m_xres);
    //glViewport(0, 0, 1024, 1024);

    m_fluidDispShader.draw(m_advdiffShader.getInitCondTextureID());

    // extract some info


}

gpuWeather::~gpuWeather()
{
    //dtor
}
