`ifndef LAB3_DEFINE
`define LAB3_DEFINE

`define DATA_BITS 32
`define FILT_R 3
`define FILT_S 3

/* PE Define */
`define IFMAP_SIZE 8
`define FILTER_SIZE 8
`define PSUM_SIZE 32
// `define IFMAP_SPAD_LEN 12
// `define FILTER_SPAD_LEN 48
// `define OFMAP_SPAD_LEN 4
// `define IFMAP_INDEX_BIT 4
// `define FILTER_INDEX_BIT 6
// `define OFMAP_INDEX_BIT 2
// `define OFMAP_COL_BIT 5

/* PE Array Define*/
`define NUMS_PE_ROW 12
`define NUMS_PE_COL 6
`define YID_BITS 4
`define XID_BITS 3
`define DEFAULT_XID  (2**`XID_BITS - 1)
`define DEFAULT_YID  (2**`YID_BITS - 1)
`define DATA_SIZE 32
`define CONFIG_SIZE 12      // {p[1:0] q[1:0] F[7:0]}

// CONTROLLER CONFIG
//              m   e   p   q   r   t   C   M
//  L0          64  6   4   1   1   4   1   64
//  L1~3        64  3   4   4   4   2   64  64
//  L4          1   6   1   4   4   1   64  1

// PE CONFIG
//              p       F       q
//  L0          2'd3    8'd255   2'd0
//  L1~3        2'd3    8'd255   2'd3
//  L4          2'd0    8'd255   2'd3

`define GLB_IFADDR_OFFSET  32'd0
`define GLB_WADDR_OFFSET   32'd32768
`define GLB_OPADDR_OFFSET  32'd33920
`define GLB_BIAS_OFFSET    32'd427136

`endif
