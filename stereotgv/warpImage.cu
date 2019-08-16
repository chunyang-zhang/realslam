#include "stereotgv.h"

/// image to warp
texture<float, 2, cudaReadModeElementType> texToWarp;
texture<float2, 2, cudaReadModeElementType> texTv;

__global__ void WarpingKernel(int width, int height, int stride,
	const float2 *warpUV, float *out)
{
	const int ix = threadIdx.x + blockIdx.x * blockDim.x;
	const int iy = threadIdx.y + blockIdx.y * blockDim.y;

	const int pos = ix + iy * stride;

	if (ix >= width || iy >= height) return;

	float x = ((float)ix + warpUV[pos].x + 0.5f) / (float)width;
	float y = ((float)iy + warpUV[pos].y + 0.5f) / (float)height;

	out[pos] = tex2D(texToWarp, x, y);
}

void StereoTgv::WarpImage(const float *src, int w, int h, int s,
	const float2 *warpUV, float *out)
{
	dim3 threads(BlockWidth, BlockHeight);
	dim3 blocks(iDivUp(w, threads.x), iDivUp(h, threads.y));

	// mirror if a coordinate value is out-of-range
	texToWarp.addressMode[0] = cudaAddressModeMirror;
	texToWarp.addressMode[1] = cudaAddressModeMirror;
	texToWarp.filterMode = cudaFilterModeLinear;
	texToWarp.normalized = true;

	cudaChannelFormatDesc desc = cudaCreateChannelDesc<float>();

	cudaBindTexture2D(0, texToWarp, src, w, h, s * sizeof(float));

	WarpingKernel << <blocks, threads >> > (w, h, s, warpUV, out);
}


// **************************************************
// ** Find Warping vector direction (tvx2, tvy2) for Fisheye Stereo
// **************************************************

__global__ void TgvFindWarpingVectorKernel(const float2 *warpUV,
	int width, int height, int stride, float2 *tv2)
{
	const int ix = threadIdx.x + blockIdx.x * blockDim.x;
	const int iy = threadIdx.y + blockIdx.y * blockDim.y;

	const int pos = ix + iy * stride;

	if (ix >= width || iy >= height) return;

	float x = ((float)ix + warpUV[pos].x + 0.5f) / (float)width;
	float y = ((float)iy + warpUV[pos].y + 0.5f) / (float)height;

	tv2[pos] = tex2D(texTv, x, y);
}

void StereoTgv::FindWarpingVector(const float2 *warpUV, const float2 *tv,
	int w, int h, int s, float2 *tv2)
{
	dim3 threads(BlockWidth, BlockHeight);
	dim3 blocks(iDivUp(w, threads.x), iDivUp(h, threads.y));

	// mirror if a coordinate value is out-of-range
	texTv.addressMode[0] = cudaAddressModeMirror;
	texTv.addressMode[1] = cudaAddressModeMirror;
	texTv.filterMode = cudaFilterModeLinear;
	texTv.normalized = true;

	cudaChannelFormatDesc desc = cudaCreateChannelDesc<float>();

	cudaBindTexture2D(0, texTv, tv, w, h, s * sizeof(float));

	TgvFindWarpingVectorKernel << <blocks, threads >> > (warpUV, w, h, s, tv2);
}

// **************************************************
// ** Compute Optical flow (u,v) for Fisheye Stereo
// **************************************************

__global__ void TgvComputeOpticalFlowVectorKernel(const float *u, const float2 *tv2,
	int width, int height, int stride, float2 *warpUV)
{
	const int ix = threadIdx.x + blockIdx.x * blockDim.x;
	const int iy = threadIdx.y + blockIdx.y * blockDim.y;

	const int pos = ix + iy * stride;

	if (ix >= width || iy >= height) return;

	float us = u[pos];
	float2 tv2s = tv2[pos];
	warpUV[pos].x = us * tv2s.x;
	warpUV[pos].y = us * tv2s.y;
}

void StereoTgv::ComputeOpticalFlowVector(const float *u, const float2 *tv2,
	int w, int h, int s, float2 *warpUV)
{
	dim3 threads(BlockWidth, BlockHeight);
	dim3 blocks(iDivUp(w, threads.x), iDivUp(h, threads.y));

	TgvComputeOpticalFlowVectorKernel << <blocks, threads >> > (u, tv2, w, h, s, warpUV);
}