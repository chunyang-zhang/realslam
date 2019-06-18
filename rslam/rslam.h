#pragma once
#include <librealsense2\rs.hpp>
#include <camerapose\CameraPose.h>
#include <opencv2/opencv.hpp>
#include "lib_link.h"
#include <viewer\Viewer.h>
#include <filereader\Filereader.h>
#include <thread>

class Rslam {
public:
	Rslam() {};
	~Rslam() {};

	enum Settings {
		D435I_848_480_60,
		D435I_640_480_60,
		T265
	};

	float GYRO_BIAS_X = 0.0011f;
	float GYRO_BIAS_Y = 0.0030f;
	float GYRO_BIAS_Z = -0.000371f;
	float GYRO_MAX10_X = 0.0716f;
	float GYRO_MAX10_Y = 0.0785f;
	float GYRO_MAX10_Z = 0.0873f;
	float GYRO_MIN10_X = -0.0698f;
	float GYRO_MIN10_Y = -0.0751f;
	float GYRO_MIN10_Z = -0.0890f;

	float GYRO_MAX5_X = 0.0960f;
	float GYRO_MAX5_Y = 0.1012f;
	float GYRO_MAX5_Z = 0.1152f;
	float GYRO_MIN5_X = -0.0890f;
	float GYRO_MIN5_Y = -0.0961f;
	float GYRO_MIN5_Z = -0.1152f;

	float GYRO_MAX_X = 0.2182f;
	float GYRO_MAX_Y = 0.2007f;
	float GYRO_MAX_Z = 0.2531f;
	float GYRO_MIN_X = -0.2147f;
	float GYRO_MIN_Y = -0.2200f;
	float GYRO_MIN_Z = -0.2496f;

	rs2::pipeline * pipe;
	rs2::context * ctx;

	//rs2::context ctx;
	//rs2::pipeline pipe = rs2::pipeline(ctx);
	rs2::align alignToColor = rs2::align(RS2_STREAM_COLOR);
	rs2::colorizer colorizer;
	rs2::frameset frameset;

	int height;
	int width;
	int fps;
	cv::Mat depth;
	cv::Mat depthVis;
	cv::Mat color;
	cv::Mat intrinsic;
	//CameraPose* cameraPose;

	double timestamps[RS2_STREAM_COUNT];
	struct Gyro {
		float x; //rate(dot) of rotation in x(rx)
		float y;
		float z;
		double ts; //timestamp
		double lastTs;
		double dt;
	} gyro;

	struct Accel {
		float x;
		float y;
		float z;
		double ts; //timestamp
		double lastTs;
		double dt;
	} accel;

	struct Pose {
		float x;
		float y;
		float z;
		float rx;
		float ry;
		float rz;
		float rw;
	} pose;

	// For Slam
	int minHessian;
	cv::cuda::SURF_CUDA surf;
	cv::Ptr< cv::cuda::DescriptorMatcher > matcher;
	cv::cuda::GpuMat d_im;
	cv::cuda::GpuMat d_keypoints;
	cv::cuda::GpuMat d_descriptors;
	std::vector< cv::KeyPoint > keypoints;

	int solveKeypointsAndDescriptors(cv::Mat im);

	// Functions
	int initialize(int width, int height, int fps, double cx, double cy, double fx, double fy);
	int initialize(Settings settings);
	int recordAll();
	int playback(const char* serialNumber);
	int run(); // poseSolver thread
	int poseSolver(); // main loop for solving pose
	int extractGyroAndAccel();
	int extractColorAndDepth();
	int extractTimeStamps();

	void updatePose();
	int getPose(); // fetcher of current pose



	// Utilities
	void visualizeImu();
	void visualizePose();
	void visualizeColor();
	void visualizeDepth();
	void visualizeKeypoints();
	cv::Mat gyroDisp;
	cv::Mat accelDisp;

	//Tools
	std::string parseDecimal(double f);

	// Tests
	int testT265();
	int runTestViewerSimpleThread();
	int testViewerSimple();
	int getFrames();
	int testStream();
	int testImu();
	int getGyro(float *roll, float* pitch, float *yaw);

	int showAlignedDepth();
	int showDepth();
	int solveRelativePose();
	static int getPose(float *x, float *y, float *z, float *roll, float *pitch, float *yaw);


};

