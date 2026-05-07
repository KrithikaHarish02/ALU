module alu(INP_VALID,OPA,OPB,CIN,CLK,RST,CMD,CE,MODE,COUT,OFLOW,RES,G,E,L,ERR);
parameter N=8;

//Input output port declaration
  input [1:0]INP_VALID;
  input [N-1:0] OPA,OPB;
  input CLK,RST,CE,MODE,CIN;
  input [3:0] CMD;
  output reg [2*N:0] RES ;
  output reg COUT ;
  output reg OFLOW;
  output reg G ;
  output reg E;
  output reg L ;
  output reg ERR ;
  reg signed [N-1:0]s_OPA;
  reg signed [N-1:0]s_OPB;

wire [N-1:0] SUM;
assign SUM=s_OPA+s_OPB;
  wire [N-1:0]DIFF;
  assign DIFF=s_OPA-s_OPB;

  // ── Multiplication Pipeline Registers ──────────────────────────
  // Stage 1: latch both operands
  reg [N-1:0]   pipe1_OPA, pipe1_OPB;
  reg            pipe1_valid;

  // Stage 2: compute partial product
  reg [2*N-1:0]  pipe2_product;
  reg            pipe2_valid;

  // Stage 3: result is committed to RES in the main always block
  reg [2*N-1:0]  pipe3_product;
  reg            pipe3_valid;
  // ───────────────────────────────────────────────────────────────

  always @(*)
  begin
    s_OPA = OPA;
    s_OPB = OPB;
  end

  // ── 3-Stage Multiplication Pipeline ───────────────────────────
  always @(posedge CLK or posedge RST) begin
    if (RST) begin
      pipe1_OPA     <= 0;  pipe1_OPB  <= 0;  pipe1_valid <= 0;
      pipe2_product <= 0;                     pipe2_valid <= 0;
      pipe3_product <= 0;                     pipe3_valid <= 0;
    end
    else if (CE) begin
      // Stage 1 - capture operands when CMD=1001 and inputs are valid
      if (MODE && (CMD == 4'b1001) && (INP_VALID == 2'b11)) begin
        pipe1_OPA   <= OPA;
        pipe1_OPB   <= OPB;
        pipe1_valid <= 1'b1;
      end else begin
        pipe1_valid <= 1'b0;
      end

      // Stage 2 - compute (OPA+1)*(OPB+1)
      if (pipe1_valid) begin
        pipe2_product <= (pipe1_OPA + 1) * (pipe1_OPB + 1);
        pipe2_valid   <= 1'b1;
      end else begin
        pipe2_valid <= 1'b0;
      end

      // Stage 3 - forward to output register
      if (pipe2_valid) begin
        pipe3_product <= pipe2_product;
        pipe3_valid   <= 1'b1;
      end else begin
        pipe3_valid <= 1'b0;
      end
    end
  end
  // ───────────────────────────────────────────────────────────────

  always@(posedge CLK or posedge RST)
    begin
      if(RST)
        begin
          RES<=0;
          COUT<=1'b0;
          OFLOW<=1'b0;
          G<=1'b0;
          E<=1'b0;
          L<=1'b0;
          ERR<=1'b0;
        end
      else if(CE)
        begin 
          if(MODE)
            begin
              case(CMD)
                4'b0000:
                  begin
                    if(INP_VALID==2'b11)
                      {COUT,RES}<=OPA+OPB;
                    else
                      ERR<=1'b1;
                  end
                4'b0001:
                  begin
                    if(INP_VALID==2'b11) 
                      begin
                        OFLOW<=(OPA<OPB)?1:0;             
                        RES<=OPA-OPB; 
                      end
                    else
                      ERR<=1'b1;
                  end
                4'b0010:
                  begin
                    if(INP_VALID==2'b11)
                      {COUT,RES}<=OPA+OPB+CIN; 
                    else
                      ERR<=1'b1;        
                  end
                4'b0011:
                  begin
                    if(INP_VALID==2'b11)
                      begin
                        OFLOW<=(OPA<OPB)?1:0;
                        RES<=OPA-OPB-CIN; 
                      end
                    else
                      ERR<=1'b1;
                  end
                4'b0100:
                  begin
                    if(INP_VALID==2'b01)
                      RES<=OPA+1;
                    else
                      ERR<=1'b1;
                  end
                4'b0101:
                  begin
                    if(INP_VALID==2'b01)
                      RES<=OPA-1;
                    else
                      ERR<=1'b1;
                  end
                4'b0110:
                  begin
                    if(INP_VALID==2'b10)
                      RES<=OPB+1;
                    else
                      ERR<=1'b1;
                  end
                4'b0111:
                  begin
                    if(INP_VALID==2'b10)
                      RES<=OPB-1; 
                    else
                      ERR<=1'b1;
                  end
                4'b1000:
                  begin
                    if(INP_VALID==2'b11)
                      begin
                        RES<=0;
                        if(OPA==OPB)
                          begin
                            E<=1'b1;
                            G<=1'b0;
                            L<=1'b0;
                          end
                        else if(OPA>OPB)
                          begin
                            E<=1'b0;
                            G<=1'b1;
                            L<=1'b0;
                          end
                        else 
                          begin
                            E<=1'b0;
                            G<=1'b0;
                            L<=1'b1;
                          end
                      end
                    else
                      ERR<=1'b1;
                  end

                // ── CMD = 1001: MULTIPLY (pipeline result commit) ──
                4'b1001:
                  begin
                    if (INP_VALID == 2'b11) begin
                      if (pipe3_valid)
                        RES <= pipe3_product;   // write result once pipeline delivers it
                    end else begin
                      ERR <= 1'b1;
                    end
                  end
                // ──────────────────────────────────────────────────

                4'b1011:
                  begin
                    if(INP_VALID==2'b11)
                      begin
                        RES<=s_OPA+s_OPB;
                        OFLOW<=(s_OPA[N-1]==s_OPB[N-1])&&((SUM[N-1])!=s_OPA[N-1]);
                        E<=(s_OPA==s_OPB);
                        G<=(s_OPA>s_OPB);
                        L<=(s_OPA<s_OPB);
                      end
                    else
                      ERR<=1'b1;
                  end	
                4'b1100:
                  begin
                    if(INP_VALID==2'b11)
                      begin
                        RES<=s_OPA-s_OPB;
                        OFLOW<=(s_OPA[N-1]==s_OPB[N-1])&&((DIFF[N-1])!=s_OPA[N-1]);
                        E<=(s_OPA==s_OPB);
                        G<=(s_OPA>s_OPB);
                        L<=(s_OPA<s_OPB);
                      end
                    else
                      ERR<=1'b1;
                  end
                default:
                  begin
                    RES<=0;
                    COUT<=1'b0;
                    OFLOW<=1'b0;
                    G<=1'b0;
                    E<=1'b0;
                    L<=1'b0;
                    ERR<=1'b0;
                  end
              endcase
            end
          else
            begin 
              RES<=0;
              COUT<=1'b0;
              OFLOW<=1'b0;
              G<=1'b0;
              E<=1'b0;
              L<=1'b0;
              ERR<=1'b0;
              case(CMD)
                4'b0000:
                  begin
                    if(INP_VALID==2'b11)
                      RES<=OPA&OPB;
                    else
                      ERR<=1'b1;
                  end
                4'b0001:
                  begin
                    if(INP_VALID==2'b11)
                      RES<=~(OPA&OPB);
                    else
                      ERR<=1'b1;
                  end
                4'b0010:
                  begin
                    if(INP_VALID==2'b11)
                      RES<=OPA|OPB;
                    else
                      ERR<=1'b1;
                  end
                4'b0011:
                  begin
                    if(INP_VALID==2'b11)
                      RES<=~(OPA|OPB);
                    else
                      ERR<=1'b1;
                  end
                4'b0100:
                  begin
                    if(INP_VALID==2'b11)
                      RES<=OPA^OPB;
                    else
                      ERR<=1'b1;
                  end
                4'b0101:
                  begin
                    if(INP_VALID==2'b11)
                      RES<=~(OPA^OPB);
                    else
                      ERR<=1'b1;
                  end
                4'b0110:
                  begin
                    if(INP_VALID==2'b01)
                      RES<=~OPA;
                    else
                      ERR<=1'b1;
                  end
                4'b0111:
                  begin
                    if(INP_VALID==2'b10)
                      RES<=~OPB;
                    else
                      ERR<=1'b1;
                  end
                4'b1000:
                  begin
                    if(INP_VALID==2'b01)
                      RES<=OPA>>1;
                    else
                      ERR<=1'b1;
                  end
                4'b1001:
                  begin
                    if(INP_VALID==2'b01)
                      RES<=OPA<<1;
                    else
                      ERR<=1'b1;
                  end
                4'b1010:
                  begin
                    if(INP_VALID==2'b10)
                      RES<=OPB>>1;
                    else
                      ERR<=1'b1;
                  end
                4'b1011:
                  begin
                    if(INP_VALID==2'b10)
                      RES<=OPB<<1;
                    else
                      ERR<=1'b1;
                  end
                4'b1100:
                  begin 
                    if(INP_VALID==2'b11)
                      begin
                        casex(OPB[7:0])
                          8'b0000_x000:RES<=OPA;
                          8'b0000_x001:RES<={OPA[N-2:0],OPA[N-1]};
                          8'b0000_x010:RES<={OPA[N-3:0],OPA[N-1:N-2]};
                          8'b0000_x011:RES<={OPA[N-4:0],OPA[N-1:N-3]};
                          8'b0000_x100:RES<={OPA[N-5:0],OPA[N-1:N-4]};
                          8'b0000_x101:RES<={OPA[N-6:0],OPA[N-1:N-5]};
                          8'b0000_x110:RES<={OPA[N-7:0],OPA[N-1:N-6]};
                          8'b0000_x111:RES<={OPA[N-8:0],OPA[N-1:N-7]};
                          default:;
                        endcase
                        ERR <= 1'b0;
                        if(OPB[7] | OPB[6] | OPB[5] | OPB[4])
                          ERR <= 1'b1;
                      end
                    else
                      ERR<=1'b1;
                  end
                4'b1101:
                  begin
                    if(INP_VALID==2'b11)
                      begin
                        casex(OPB[7:0])
                          8'b0000_x000:RES<=OPA;
                          8'b0000_x001:RES<={OPA[0],OPA[N-1:1]};
                          8'b0000_x010:RES<={OPA[1:0],OPA[N-1:2]};
                          8'b0000_x011:RES<={OPA[2:0],OPA[N-1:3]};
                          8'b0000_x100:RES<={OPA[3:0],OPA[N-1:4]};
                          8'b0000_x101:RES<={OPA[4:0],OPA[N-1:5]};
                          8'b0000_x110:RES<={OPA[5:0],OPA[N-1:6]};
                          8'b0000_x111:RES<={OPA[6:0],OPA[N-1:7]};
                          default:;
                        endcase
                        ERR <= 1'b0;
                        if(OPB[7]|OPB[6]|OPB[5]|OPB[4])
                          ERR <= 1'b1;
                      end
                    else
                      ERR<=1'b1;
                  end
                default:
                  begin
                    RES<=0;
                    COUT<=1'b0;
                    OFLOW<=1'b0;
                    G<=1'b0;
                    E<=1'b0;
                    L<=1'b0;
                    ERR<=1'b0;
                  end
              endcase
            end
        end
    end
endmodule
