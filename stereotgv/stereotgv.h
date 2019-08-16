#pragma once
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <memory.h>
#include <math.h>

#include <cuda_runtime.h>
#include <helper_cuda.h>
#include <device_launch_parameters.h>

#include "lib_link.h"

class StereoTgv {
public:
	StereoTgv();
	StereoTgv(int blockWidth, int blockHeight, int strideAlignment);
	~StereoTgv() {};

	int BlockWidth, BlockHeight, StrideAlignment;

	int width;
	int height;
	int stride;
	int dataSize8u;
	int dataSize8uc3;
	int dataSize32f;
	int dataSize32fc2;
	int dataSize32fc3;
	int dataSize32fc4;
	float baseline;
	float focal;
	bool visualizeResults;

	float beta;
	float gamma;
	float alpha0;
	float alpha1;
	float timestep_lambda;
	float lambda;
	float fScale;
	int nLevels;
	int nSolverIters;
	int nWarpIters;

	// Inputs and Outputs
	float *d_i0, *d_i1, *d_i1warp;
	uchar3 *d_i08uc3, *d_i18uc3;
	uchar *d_i08u, *d_i18u;

	float *d_i0smooth, *d_i1smooth;
	float *d_Iu, *d_Iz;
	// Output Disparity
	float* d_u, *d_du, *d_us;
	// Output Depth
	float* d_depth;
	// Warping Variables
	float2 *d_warpUV, *d_warpUVs, *d_dwarpUV;

	std::vector<float*> pI0;
	std::vector<float*> pI1;
	std::vector<int> pW;
	std::vector<int> pH;
	std::vector<int> pS;
	std::vector<int> pDataSize;

	// TGVL1 Process variables
	float *d_a, *d_b, *d_c; // Tensor
	float *d_etau, *d_etav1, *d_etav2;
	float2 *d_p;
	float4 *d_q;
	float *d_u_, *d_u_s, *d_u_last;
	float2 *d_v, *d_vs, *d_v_, *d_v_s;
	float4 *d_gradv;
	float2 *d_Tp;

	// Vector Fields
	cv::Mat translationVector;
	cv::Mat calibrationVector;
	float2 *d_tvForward;
	float2 *d_tvBackward;
	float2 *d_tv2;
	float2 *d_cv;
	float *d_i1calibrated;
	std::vector<float2*> pTvForward;
	std::vector<float2*> pTvBackward;

	// 3D
	float3 *d_X;

	// Debug
	float *debug_depth;

	cv::Mat im0pad, im1pad;


	int initialize(int width, int height, float beta, float gamma,
		float alpha0, float alpha1, float timestep_lambda, float lambda,
		int nLevels, float fScale, int nWarpIters, int nSolverIters);
	int loadVectorFields(cv::Mat translationVector, cv::Mat calibrationVector);
	int copyImagesToDevice(cv::Mat i0, cv::Mat i1);
	int solveStereoForward();

	// UTILITIES
	int iAlignUp(int n);
	int iDivUp(int n, int m);
	template<typename T> void Swap(T &a, T &ax);
	template<typename T> void Copy(T &dst, T &src);

	// Kernels
	void ScalarMultiply(float *src, float scalar, int w, int h, int s);
	//void ScalarMultiply(float2 *src, float scalar, int w, int h, int s);
	void ScalarMultiply(float *src, float scalar, int w, int h, int s, float *dst);
	void ScalarMultiply(float2 *src, float scalar, int w, int h, int s, float2 *dst);
	void Add(float2 *src1, float2* src2, int w, int h, int s, float2* dst);
	void Subtract(float *minuend, float* subtrahend, int w, int h, int s, float* difference);
	void Downscale(const float *src, int width, int height, int stride,
		int newWidth, int newHeight, int newStride, float *out);
	void Downscale(const float2 *src, int width, int height, int stride,
		int newWidth, int newHeight, int newStride, float2 *out);
	void Downscale(const float *src, int width, int height, int stride,
		int newWidth, int newHeight, int newStride, float scale, float *out);
	void Downscale(const float2 *src, int width, int height, int stride,
		int newWidth, int newHeight, int newStride, float scale, float2 *out);
	void Cv8uToGray(uchar * d_iCv8u, float *d_iGray, int w, int h, int s);
	void Cv8uc3ToGray(uchar3 * d_iRgb, float *d_iGray, int w, int h, int s);
	void WarpImage(const float *src, int w, int h, int s,
		const float2 *warpUV, float *out);
	void ComputeOpticalFlowVector(const float *u, const float2 *tv2,
		int w, int h, int s, float2 *warpUV);
	void FindWarpingVector(const float2 *warpUV, const float2 *tv, int w, int h, int s,
		float2 *tv2);
	void CalcTensor(float* gray, float beta, float gamma, int size_grad,
		int w, int h, int s, float* a, float* b, float* c);
	void Gaussian(float* input, int w, int h, int s, float* output);
	void SolveEta(float alpha0, float alpha1,
		float* a, float *b, float* c,
		int w, int h, int s, float* etau, float* etav1, float* etav2);
	void Clone(float* dst, int w, int h, int s, float* src);
	void Clone(float2* dst, int w, int h, int s, float2* src);
	void ComputeDerivatives(float *I0, float *I1,
		int w, int h, int s, float *Ix, float *Iy, float *Iz);
	void ComputeDerivativesFisheye(float *I0, float *I1, float2 *vector,
		int w, int h, int s, float *Iw, float *Iz);
	void Upscale(const float *src, int width, int height, int stride,
		int newWidth, int newHeight, int newStride, float scale, float *out);
	void Upscale(const float2 *src, int width, int height, int stride,
		int newWidth, int newHeight, int newStride, float scale, float2 *out);

	void UpdateDualVariablesTGV(float* u_, float2 *v_, float alpha0, float alpha1, float sigma,
		float eta_p, float eta_q, float* a, float* b, float* c,
		int w, int h, int s,
		float4* grad_v, float2* p, float4* q);
	void ThresholdingL1(float2* Tp, )
	void UpdatePrimalVariables(float2* Tp, float* u_, float2* v_, float2* p, float4* q,
		float* a, float* b, float* c,
		float tau, float* eta_u, float* eta_v1, float* eta_v2,
		float alpha0, float alpha1, float mu,
		int w, int h, int s,
		float* u, float2* v, float* u_s, float2* v_s);
	void SolveTp(float* a, float* b, float* c, float2* p, 
		int w, int h, int s, float2* Tp);

};