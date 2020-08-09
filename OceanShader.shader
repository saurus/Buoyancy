shader_type spatial;
render_mode skip_vertex_transform, cull_front, unshaded;

uniform vec4 amplitude0;
uniform vec4 steepness0;
uniform vec4 wind_directionX0;
uniform vec4 wind_directionY0;
uniform vec4 frequency0;

uniform vec4 amplitude1;
uniform vec4 steepness1;
uniform vec4 wind_directionX1;
uniform vec4 wind_directionY1;
uniform vec4 frequency1;

uniform vec4 amplitude2;
uniform vec4 steepness2;
uniform vec4 wind_directionX2;
uniform vec4 wind_directionY2;
uniform vec4 frequency2;

uniform int waves_vectors = 1;

uniform sampler2D noise;
uniform float noise_amplitude = 0.0;
uniform float noise_frequency = 0.0;
uniform float noise_speed = 0.0;

uniform samplerCube environment;
uniform vec4 water_color: hint_color;

uniform float project_bias = 1.2;

uniform float time_offset;

mat3 getRotation(mat4 camera) {
	return mat3(
		camera[0].xyz,
		camera[1].xyz,
		camera[2].xyz
	);
}

vec3 getPosition(mat4 camera) {
	return -camera[3].xyz * getRotation(camera);
}

vec2 getImagePlan(mat4 projection, vec2 uv) {
	float focal = projection[0].x * project_bias;
	float aspect = projection[1].y * project_bias;
	
	return vec2((uv.x - 0.5) * aspect, (uv.y - 0.5) * focal);
}

vec3 getCamRay(mat4 projection, mat3 rotation, vec2 screenUV) {
	return vec3(screenUV.xy, projection[0].x) * rotation;
}

vec3 interceptPlane(vec3 source, vec3 dir, vec4 plane) {
	float dist = (-plane.w - dot(plane.xyz, source)) / dot(plane.xyz, dir);
	if(dist < 0.0) {
		return source + dir * dist;
	} else {
		return -(vec3(source.x, plane.w, source.z) + vec3(dir.x, plane.w, dir.z) * 100000.0);
	}
}

vec3 computeProjectedPosition(in vec3 cam_pos, in mat3 cam_rot, in mat4 projection, in vec2 uv) {
	vec2 screenUV = getImagePlan(projection, uv);
	
	vec3 ray = getCamRay(projection, cam_rot, screenUV);
	return interceptPlane(cam_pos, ray, vec4(0.0,-1.0,0.0,0.0));
}

float noise3D(vec3 p) {
	float iz = floor(p.z);
	float fz = fract(p.z);
	vec2 a_off = vec2(0.852, 29.0) * iz*0.643;
	vec2 b_off = vec2(0.852, 29.0) * (iz+1.0)*0.643;
	float a = texture(noise, p.xy + a_off).r;
	float b = texture(noise, p.xy + b_off).r;
	
	return mix(a, b, fz);
}

vec3 waves_calc(float amp, float steep, float windX, float windY, float w, vec2 pos, float time)
{
	vec3 r = vec3(0);
	vec2 dir = vec2(windX, windY);
	float phase = 2.0 * w;
	float W = dot(w*dir, pos) + phase*time;
	r.xz = (steep / w) * dir * cos(W);
	r.y = amp * sin(W);
	return r;
}

vec3 wave_v4(vec3 new_p, vec4 amplitude, vec4 steepness, vec4 windX, vec4 windY, vec4 frequency, vec2 pos, float time) {
	new_p += waves_calc(amplitude.x, steepness.x, windX.x, windY.x, frequency.x, pos, time);
	new_p += waves_calc(amplitude.y, steepness.y, windX.y, windY.y, frequency.y, pos, time);
	new_p += waves_calc(amplitude.z, steepness.z, windX.z, windY.z, frequency.z, pos, time);
	new_p += waves_calc(amplitude.w, steepness.w, windX.w, windY.w, frequency.w, pos, time);
	return new_p;
}

vec3 wave(vec2 pos, float time) {
	vec3 new_p = vec3(pos.x, 0.0, pos.y);
	
	new_p = wave_v4(new_p, amplitude0, steepness0, wind_directionX0, wind_directionY0, frequency0, pos, time);
	if (waves_vectors > 1)
		new_p = wave_v4(new_p, amplitude1, steepness1, wind_directionX1, wind_directionY1, frequency1, pos, time);

	if (waves_vectors > 2)
		new_p = wave_v4(new_p, amplitude2, steepness2, wind_directionX2, wind_directionY2, frequency2, pos, time);
	if(noise_amplitude > 0.0)
		new_p.y += noise3D(vec3(pos.xy*noise_frequency, time*noise_speed))*noise_amplitude;
	return new_p;
}

vec3 wave_normal(vec2 pos, float time, float res) {
	vec3 right = wave(pos - vec2(res, res), time);
	vec3 left = wave(pos + vec2(-res, res), time);
	vec3 down = wave(pos + vec2(res, 0), time);
	return -normalize(cross(right-down, left-down));
//	Original code, using four points
//	vec3 right = wave(pos + vec2(res, 0.0), time);
//	vec3 left = wave(pos - vec2(res, 0.0), time);
//	vec3 down = wave(pos - vec2(0.0, res), time);
//	vec3 up = wave(pos + vec2(0.0, res), time);
//	return -normalize(cross(right-left, down-up));
}

varying vec2 vert_coord;
varying float vert_dist;

varying vec3 eyeVector;

void vertex() {
	vec2 screen_uv = VERTEX.xz + 0.5;
	
	mat4 projected_cam_matrix = INV_CAMERA_MATRIX;
	
	mat3 camRotation = getRotation(projected_cam_matrix);
	vec3 camPosition = getPosition(projected_cam_matrix);
	
	VERTEX = computeProjectedPosition(camPosition, camRotation, PROJECTION_MATRIX, screen_uv);
	
	vec2 pre_displace = VERTEX.xz;
	VERTEX = wave(VERTEX.xz, time_offset);
	if( any(lessThan(screen_uv, vec2(0.0))) || any(greaterThan(screen_uv, vec2(1.0))) )
		VERTEX.xz = pre_displace;
	
	eyeVector = normalize(VERTEX - camPosition);
	vert_coord = VERTEX.xz;
	VERTEX = (INV_CAMERA_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vert_dist = length(VERTEX);
}

float fresnel(float n1, float n2, float cos_theta) {
	float R0 = pow((n1 - n2) / (n1+n2), 2);
	return R0 + (1.0 - R0)*pow(1.0 - cos_theta, 5);
}

void fragment() {
	NORMAL = wave_normal(vert_coord, time_offset, vert_dist/40.0);
	NORMAL = mix(NORMAL, vec3(0, -1, 0), min(vert_dist/1000.0, 1));
	
	float eye_dot_norm = dot(eyeVector, NORMAL);
	float n1 = 1.0, n2 = 1.3333;
	
	float reflectiveness = fresnel(n1, n2, abs(eye_dot_norm));
	
	vec3 reflect_global = texture(environment, reflect(eyeVector, NORMAL)).rgb;
	vec3 refract_global;
	if(eye_dot_norm < 0.0)
		refract_global = texture(environment, refract(eyeVector, NORMAL, n1/n2)).rgb;
	else
		refract_global = water_color.rgb;
	
	ALBEDO = mix(refract_global, reflect_global, reflectiveness);
	ALPHA = 0.95;
}