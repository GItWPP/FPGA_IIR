`timescale 1ns / 1ps
module TB();

reg         	sys_clk  ;  //系统时钟
reg         	sys_rst_n;  //系统复位

reg 			conv	 ; 	
reg 			conv_done;     

reg 	[15:0]	cnt;
reg 	[31:0]	cnt_delay5ms;
reg             delay_flag;

wire signed [15:0] data_out;
wire 			   data_out_val;

//data flag
reg 	[15:0]	cnt_data;
reg             data_done;
always@(posedge sys_clk or negedge sys_rst_n)begin
	if(sys_rst_n == 1'b0)
		cnt_data <= 16'd0;
	else	if(cnt_data == 16'd490) //4999 10khz
		cnt_data <= 16'd0;
	else
		cnt_data <= cnt_data + 1'b1;
end

always@(posedge sys_clk or negedge sys_rst_n)begin
	if(sys_rst_n == 1'b0)
		data_done <= 1'b0;
	else	if(cnt == 16'd490)
		data_done <= 1'b1;
	else
		data_done <= 1'b0;
end


//20kHZ sample
always@(posedge sys_clk or negedge sys_rst_n)begin
	if(sys_rst_n == 1'b0)
		cnt <= 16'd0;
	else	if(cnt == 16'd2499) //4999 10khz
		cnt <= 16'd0;
	else
		cnt <= cnt + 1'b1;
end

always@(posedge sys_clk or negedge sys_rst_n)begin
	if(sys_rst_n == 1'b0)begin
		conv	  <= 1'b1;
		conv_done <= 1'b0;
	end   else	if(cnt == 16'd2499)begin //4999 10khz
		conv	  <= 1'b0;
		conv_done <= 1'b1;
	end   else	begin
		conv	  <= 1'b1;
		conv_done <= 1'b0;
	end
end

//delay
always@(posedge sys_clk or negedge sys_rst_n)begin
	if(sys_rst_n == 1'b0)
		cnt_delay5ms <= 32'd0;
	else	if(cnt_delay5ms == 32'd249999) //delay 5ms
		cnt_delay5ms <= cnt_delay5ms;
	else
		cnt_delay5ms <= cnt_delay5ms + 1'b1;
end

always@(posedge sys_clk or negedge sys_rst_n)begin
	if(sys_rst_n == 1'b0)
		delay_flag <= 1'b0;
	else	if(cnt_delay5ms == 32'd2499999) 
		delay_flag <= 1'b1;
	else
		delay_flag <= delay_flag;
end

always #10 sys_clk = ~sys_clk;

initial
	begin
		sys_clk   = 1'b1;
        sys_rst_n <= 1'b0;
		#20
        sys_rst_n <= 1'b1;
	end


//测试信号

// 测试信号参数
reg signed [15:0] data_in;
reg [31:0] sample_counter;
real time_ms;
real f1 = 20.0;    // 信号频率 200Hz
real f2 = 100.0;    // 噪声频率 400Hz
real f3 = 40.0;    // 噪声频率 40Hz
real f4 = 80.0;    // 噪声频率 80Hz

real fs_real = 10000.0;

reg signed [15:0] signal_200hz;
reg signed [15:0] signal_1000hz;
reg signed [15:0] signal_40hz;
reg signed [15:0] signal_80hz;
reg signed [15:0] noise;
integer noise_seed = 12345;
    
always @(posedge sys_clk or negedge sys_rst_n) begin
	if (!sys_rst_n) begin
		sample_counter <= 0;
		time_ms <= 0;
		signal_200hz <= 0;
		signal_1000hz <= 0;
		signal_40hz <= 0;
		signal_80hz <= 0;
		noise <= 0;
	end
	else begin
		// 只在使能有效时更新时�?
		if (data_done) begin // && delay_flag
			sample_counter <= sample_counter + 1;
			time_ms = sample_counter * (1000.0 / fs_real);
			
			// 生成200Hz正弦信号（幅�?0.7，Q1.15格式�?
			signal_200hz <= $rtoi(0.28 * 32767 * $sin(3.1415926 * f1 * time_ms / 1000.0));
			
			// 生成1000Hz干扰信号（幅�?0.3�?
			signal_1000hz <= $rtoi(0.2 * 32767 * $sin(3.1415926 * f2 * time_ms / 1000.0));
			
			//
			signal_40hz <= $rtoi(0.2 * 32767 * $sin(3.1415926 * f3 * time_ms / 1000.0));
			
			//
			signal_80hz <= $rtoi(0.2 * 32767 * $sin(3.1415926 * f4 * time_ms / 1000.0));
			
			// 生成高斯白噪声（幅度0.08�?
			noise <= $rtoi(0.3 * 32767 * ($random(noise_seed) % 1000) / 1000.0);
		end
	end
end 

//DATA
always @(posedge sys_clk or negedge sys_rst_n) begin
	if (!sys_rst_n) begin
		data_in <= 0;
	end else if(delay_flag)begin
		data_in <= signal_200hz + noise;
	end else begin
		data_in <= signal_200hz + signal_1000hz  + signal_40hz + signal_80hz;
	end
end 

iir_lp_50hz_20khz	iir_lp_50hz_20khz_inst
(
    .sys_clk	(sys_clk  ),
    .sys_rst_n	(sys_rst_n),

    .din		(data_in),
    .din_valid	(conv_done),

    .dout		(data_out),
    .dout_valid	(data_out_val)
);

endmodule