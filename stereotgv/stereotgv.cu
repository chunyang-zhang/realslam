#include "stereotgv.h"

StereoTgv::StereoTgv() {
	this->BlockHeight = 12;
	this->BlockWidth = 32;
	this->StrideAlignment = 32;
}

StereoTgv::StereoTgv(int blockWidth, int blockHeight, int strideAlignment) {
	this->BlockHeight = blockHeight;
	this->BlockWidth = blockWidth;
	this->StrideAlignment = strideAlignment;
}

int StereoTgv::initialize(int width, int height, float beta, float gamma,
	float alpha0, float alpha1, float timestep_lambda, float lambda,
	int nLevels, float fScale, int nWarpIters, int nSolverIters) {
	// Set memory for lidarinput (32fc1), lidarmask(32fc1), image0, image1 (8uc3), depthout (32fc1)
	// flowinput (32fc2), depthinput (32fc1)
	this->width = width;
	this->height = height;
	this->stride = this->iAlignUp(width);

	this->beta = beta;
	this->gamma = gamma;
	this->alpha0 = alpha0;
	this->alpha1 = alpha1;
	this->timestep_lambda = timestep_lambda;
	this->lambda = lambda;
	this->fScale = fScale;
	this->nLevels = nLevels;
	this->nWarpIters = nWarpIters;
	this->nSolverIters = nSolverIters;

	pI0 = std::vector<float*>(nLevels);
	pI1 = std::vector<float*>(nLevels);
	pW = std::vector<int>(nLevels);
	pH = std::vector<int>(nLevels);
	pS = std::vector<int>(nLevels);
	pDataSize = std::vector<int>(nLevels);
	pTvForward = std::vector<float2*>(nLevels);
	pTvBackward = std::vector<float2*>(nLevels);

	int newHeight = height;
	int newWidth = width;
	int newStride = iAlignUp(width);
	//std::cout << "Pyramid Sizes: " << newWidth << " " << newHeight << " " << newStride << std::endl;
	for (int level = 0; level < nLevels; level++) {
		pDataSize[level] = newStride * newHeight * sizeof(float);
		checkCudaErrors(cudaMalloc(&pI0[level], pDataSize[level]));
		checkCudaErrors(cudaMalloc(&pI1[level], pDataSize[level]));
		checkCudaErrors(cudaMalloc(&pTvForward[level], 2 * pDataSize[level]));
		checkCudaErrors(cudaMalloc(&pTvBackward[level], 2 * pDataSize[level]));

		pW[level] = newWidth;
		pH[level] = newHeight;
		pS[level] = newStride;
		newHeight = newHeight / fScale;
		newWidth = newWidth / fScale;
		newStride = iAlignUp(newWidth);
	}

	dataSize8u = stride * height * sizeof(uchar);
	dataSize8uc3 = stride * height * sizeof(uchar3);
	dataSize32f = stride * height * sizeof(float);
	dataSize32fc2 = stride * height * sizeof(float2);
	dataSize32fc3 = stride * height * sizeof(float3);
	dataSize32fc4 = stride * height * sizeof(float4);

	// Inputs and Outputs
	checkCudaErrors(cudaMalloc(&d_i0, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_i1, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_i1warp, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_i08u, dataSize8u));
	checkCudaErrors(cudaMalloc(&d_i18u, dataSize8u));
	checkCudaErrors(cudaMalloc(&d_i08uc3, dataSize8uc3));
	checkCudaErrors(cudaMalloc(&d_i18uc3, dataSize8uc3));
	checkCudaErrors(cudaMalloc(&d_i0smooth, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_i1smooth, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_Iu, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_Iz, dataSize32f));
	// Output Disparity
	checkCudaErrors(cudaMalloc(&d_u, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_du, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_us, dataSize32f));
	// Output Depth
	checkCudaErrors(cudaMalloc(&d_depth, dataSize32f));
	// Warping Variables
	checkCudaErrors(cudaMalloc(&d_warpUV, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_dwarpUV, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_warpUVs, dataSize32fc2));

	// Vector Fields
	checkCudaErrors(cudaMalloc(&d_tvForward, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_tvBackward, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_tv2, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_cv, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_i1calibrated, dataSize32f));

	// Process variables
	checkCudaErrors(cudaMalloc(&d_a, dataSize32f)); // Tensor
	checkCudaErrors(cudaMalloc(&d_b, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_c, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_etau, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_etav1, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_etav2, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_p, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_q, dataSize32fc4));
	
	checkCudaErrors(cudaMalloc(&d_u_, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_u_last, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_u_s, dataSize32f));
	checkCudaErrors(cudaMalloc(&d_v, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_vs, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_v_, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_v_s, dataSize32fc2));
	checkCudaErrors(cudaMalloc(&d_gradv, dataSize32fc4));
	checkCudaErrors(cudaMalloc(&d_Tp, dataSize32fc2));

	// 3D
	checkCudaErrors(cudaMalloc(&d_X, dataSize32fc3));

	// Debugging
	checkCudaErrors(cudaMalloc(&debug_depth, dataSize32f));

	return 0;
}


int StereoTgv::loadVectorFields(cv::Mat translationVector, cv::Mat calibrationVector) {
	// Padding
	cv::Mat translationVectorPad = cv::Mat(height, stride, CV_32FC2);
	cv::Mat calibrationVectorPad = cv::Mat(height, stride, CV_32FC2);
	cv::copyMakeBorder(translationVector, translationVectorPad, 0, 0, 0, stride - width, cv::BORDER_CONSTANT, 0);
	cv::copyMakeBorder(calibrationVector, calibrationVectorPad, 0, 0, 0, stride - width, cv::BORDER_CONSTANT, 0);

	// Translation Vector Field
	translationVector = cv::Mat(height, stride, CV_32FC2);
	calibrationVector = cv::Mat(height, stride, CV_32FC2);

	checkCudaErrors(cudaMemcpy(d_tvForward, (float2 *)translationVector.ptr(), dataSize32f, cudaMemcpyHostToDevice));

	pTvForward[0] = d_tvForward;
	ScalarMultiply(d_tvForward, -1.0f, width, height, stride, d_tvBackward);
	pTvBackward[0] = d_tvBackward;
	for (int level = 1; level < nLevels; level++) {
		//std::cout << pW[level] << " " << pH[level] << " " << pS[level] << std::endl;
		Downscale(pTvForward[level - 1], pW[level - 1], pH[level - 1], pS[level - 1],
			pW[level], pH[level], pS[level], pTvForward[level]);
		Downscale(pTvBackward[level - 1], pW[level - 1], pH[level - 1], pS[level - 1],
			pW[level], pH[level], pS[level], pTvBackward[level]);

	}

	// Calibration Vector Field
	checkCudaErrors(cudaMemcpy(d_cv, (float2 *)calibrationVector.ptr(), dataSize32fc2, cudaMemcpyHostToDevice));
	return 0;
}


int StereoTgv::copyImagesToDevice(cv::Mat i0, cv::Mat i1) {
	// Padding
	cv::copyMakeBorder(i0, im0pad, 0, 0, 0, stride - width, cv::BORDER_CONSTANT, 0);
	cv::copyMakeBorder(i1, im1pad, 0, 0, 0, stride - width, cv::BORDER_CONSTANT, 0);

	if (i0.type() == CV_8U) {
		checkCudaErrors(cudaMemcpy(d_i08u, (uchar *)im0pad.ptr(), dataSize8u, cudaMemcpyHostToDevice));
		checkCudaErrors(cudaMemcpy(d_i18u, (uchar *)im1pad.ptr(), dataSize8u, cudaMemcpyHostToDevice));
		// Convert to 32F
		Cv8uToGray(d_i08u, pI0[0], width, height, stride);
		Cv8uToGray(d_i18u, pI1[0], width, height, stride);
	}
	else if (i0.type() == CV_32F) {
		checkCudaErrors(cudaMemcpy(pI0[0], (float *)im0pad.ptr(), dataSize32f, cudaMemcpyHostToDevice));
		checkCudaErrors(cudaMemcpy(pI1[0], (float *)im1pad.ptr(), dataSize32f, cudaMemcpyHostToDevice));
	}
	else if (i0.type() == CV_8UC3){
		checkCudaErrors(cudaMemcpy(d_i08uc3, (uchar3 *)im0pad.ptr(), dataSize8uc3, cudaMemcpyHostToDevice));
		checkCudaErrors(cudaMemcpy(d_i18uc3, (uchar3 *)im1pad.ptr(), dataSize8uc3, cudaMemcpyHostToDevice));
		// Convert to 32F
		Cv8uc3ToGray(d_i08uc3, pI0[0], width, height, stride);
		Cv8uc3ToGray(d_i18uc3, pI1[0], width, height, stride);
	}
	return 0;
}


int StereoTgv::solveStereoForward() {
	// Warp i1 using vector fields
	WarpImage(pI1[0], width, height, stride, d_cv, d_i1calibrated);
	Swap(pI1[0], d_i1calibrated);

	checkCudaErrors(cudaMemset(d_u, 0, dataSize32f));
	checkCudaErrors(cudaMemset(d_warpUV, 0, dataSize32fc2));
	// Construct pyramid
	for (int level = 1; level < nLevels; level++) {
		Downscale(pI0[level - 1], pW[level - 1], pH[level - 1], pS[level - 1],
			pW[level], pH[level], pS[level],pI0[level]);
		Downscale(pI1[level - 1], pW[level - 1], pH[level - 1], pS[level - 1],
			pW[level], pH[level], pS[level], pI1[level]);
	}

	ComputeOpticalFlowVector(d_u, d_tvForward, pW[0], pH[0], pS[0], d_warpUV);

	/*cv::Mat calibrated = cv::Mat(height, stride, CV_32F);
	checkCudaErrors(cudaMemcpy((float *)calibrated.ptr(), ps_disparity, width * height * sizeof(float), cudaMemcpyDeviceToHost));
	cv::imshow("calibrated", calibrated/(float)planeSweepMaxDisparity);*/

	// Solve stereo
	for (int level = nLevels - 1; level >= 0; level--) {
		int M = pH[level];
		int N = pS[level];
		float tau = 1.0f;
		float sigma = 1.0f / tau;
		float eta_p = 3.0f;
		float eta_q = 2.0f;

		// Calculate anisotropic diffucion tensor
		Gaussian(pI0[level], pW[level], pH[level], pS[level], d_i0smooth);
		CalcTensor(d_i0smooth, beta, gamma, 2, pW[level], pH[level], pS[level], d_a, d_b, d_c);
		SolveEta(alpha0, alpha1, d_a, d_b, d_c, 
			pW[level], pH[level], pS[level], d_etau, d_etav1, d_etav2);

		for (int warpIter = 0; warpIter < nWarpIters; warpIter++) {
			checkCudaErrors(cudaMemset(d_p, 0, dataSize32fc2));
			checkCudaErrors(cudaMemset(d_q, 0, dataSize32fc4));
			checkCudaErrors(cudaMemset(d_v, 0, dataSize32fc2));
			Clone(d_v_, pW[level], pH[level], pS[level], d_v);
			checkCudaErrors(cudaMemset(d_gradv, 0, dataSize32fc4));
			checkCudaErrors(cudaMemset(d_du, 0, dataSize32f));

			FindWarpingVector(d_warpUV, pTvForward[level], pW[level], pH[level], pS[level], d_tv2);
			WarpImage(pI1[level], pW[level], pH[level], pS[level], d_warpUV, d_i1warp);
			ComputeDerivativesFisheye(pI0[level], d_i1warp, pTvForward[level], 
				pW[level], pH[level], pS[level], d_Iu, d_Iz);
			Clone(d_u_last, pW[level], pH[level], pS[level], d_u_);
			
			// Inner iteration
			for (int iter = 0; iter < nSolverIters; iter++) {
				float mu;
				if (sigma < 1000) mu = 1 / sqrt(1 + 0.7 * tau * timestep_lambda);
				else mu = 1;

				// Solve Dual Variable
				UpdateDualVariablesTGV(d_u_, d_v_, alpha0, alpha1, sigma, eta_p, eta_q,
					d_a, d_b, d_c, pW[level], pH[level], pS[level],
					 d_gradv, d_p, d_q);
				// Solve Thresholding
				// Solve Primal Variable
				SolveTp(d_a, d_b, d_c, d_p, pW[level], pH[level], pS[level], d_Tp);
				UpdatePrimalVariablesL2(d_Tp, d_u_, d_v_, d_p, d_q, d_a, d_b, d_c,
					d_Iu, d_Iz,
					tau, d_etau, d_etav1, d_etav2, alpha0, alpha1, mu,
					pW[level], pH[level], pS[level], d_u, d_v, d_u_s, d_v_s);
				Clone(d_u_, pW[level], pH[level], pS[level], d_u_s);
				Clone(d_v_, pW[level], pH[level], pS[level], d_v_s);
			}

			// Calculate d_warpUV
			Subtract(d_u_, d_u_last, pW[level], pH[level], pS[level], d_du);
			ComputeOpticalFlowVector(d_du, d_tv2, pW[level], pH[level], pS[level], d_dwarpUV);
			Add(d_warpUV, d_dwarpUV, pW[level], pH[level], pS[level], d_warpUV);
		}

		// Upscale
		if (level > 0)
		{
			float scale = fScale;
			Upscale(d_u, pW[level], pH[level], pS[level], pW[level - 1], pH[level - 1], pS[level - 1], scale, d_us);
			Upscale(d_warpUV, pW[level], pH[level], pS[level], pW[level - 1], pH[level - 1], pS[level - 1], scale, d_warpUVs);
			Swap(d_u, d_us);
			Swap(d_warpUV, d_warpUVs);
		}
	}

	/*Clone(d_w, width, height, stride, d_wForward);

	if (visualizeResults) {
		FlowToHSV(d_u, d_v, width, height, stride, d_uvrgb, flowScale);
	}*/

	return 0;
}

// Utilities
int StereoTgv::iAlignUp(int n)
{
	int m = this->StrideAlignment;
	int mod = n % m;

	if (mod)
		return n + m - mod;
	else
		return n;
}

int StereoTgv::iDivUp(int n, int m)
{
	return (n + m - 1) / m;
}

template<typename T> void StereoTgv::Swap(T &a, T &ax)
{
	T t = a;
	a = ax;
	ax = t;
}

template<typename T> void StereoTgv::Copy(T &dst, T &src)
{
	dst = src;
}