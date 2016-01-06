class AdolC < Formula
  desc "Automatic Differentiation by Overloading in C/C++"
  homepage "https://projects.coin-or.org/ADOL-C"
  url "http://www.coin-or.org/download/source/ADOL-C/ADOL-C-2.6.0.tgz"
  sha256 "add322a59f4b038ed24a53cf848235c0a22bf27ac00a389e8e594b2cfb1bb2f0"
  head "https://projects.coin-or.org/svn/ADOL-C/trunk/", :using => :svn

  bottle do
    revision 1
    sha256 "5905ef5d9019122e20139820eee3a9da55f5260300d7eb9a77863837c70cfd57" => :yosemite
    sha256 "d416356ba3c00b9dadd4ef547ffcbe011c24b0a97fc9fb8ee6b0dcb283a07998" => :mavericks
    sha256 "ddd86b44e40b432df17e909b02d429eac9b219311c96de6f851eac79c7dd0751" => :mountain_lion
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "colpack" => :recommended

  needs :cxx11

  def install
    ENV.cxx11

    # Configure may get automatically regenerated. So patch configure.ac.
    inreplace %w[configure configure.ac] do |s|
      s.gsub! "lib64", "lib"
    end

    args =  ["--prefix=#{prefix}", "--enable-sparse"]
    args << "--with-colpack=#{Formula["colpack"].opt_prefix}" if build.with? "colpack"
    args << "--with-openmp-flag=-fopenmp" if ENV.compiler != :clang
    args << "--enable-ulong" if MacOS.prefer_64_bit?

    ENV.append_to_cflags "-I#{buildpath}/ADOL-C/include/adolc"
    system "./configure", *args
    system "make", "install"
    system "make", "test"

    # move config.h to include as some packages require this info
    (include/"adolc").install "ADOL-C/src/config.h"
    doc.install "ADOL-C/doc/adolc-manual.pdf"
  end

  test do
    (testpath/"test.cpp").write <<-EOS
      #include <adolc/adouble.h>
      #include <adolc/drivers/drivers.h>
      #include <adolc/taping.h>
      int main(void) {
        int n = 10, i, j;
        size_t tape_stats[STAT_SIZE];
        double* xp = new double[n];
        double  yp = 0.0;
        adouble* x = new adouble[n];
        adouble  y = 1;
        for (i = 0; i < n; i++)
          xp[i] = (i + 1.0) / (2.0 + i);
        trace_on(1);
        for (i = 0; i < n; i++) {
            x[i] <<= xp[i];
            y *= x[i];
        }
        y >>= yp;
        delete[] x;
        trace_off();
        tapestats(1, tape_stats);
        double* g = new double[n];
        gradient(1, n, xp, g);
        double** H = (double**)malloc(n * sizeof(double*));
        for (i = 0; i < n; i++)
          H[i] = (double*)malloc((i+1) * sizeof(double));
        hessian(1, n, xp, H);
        double errg = 0;
        double errh = 0;
        for (i = 0; i < n; i++)
          errg += fabs(g[i] - yp / xp[i]);
        for (i = 0; i < n; i++)
          for (j = 0; j < n; j++)
            if (i > j)
              errh += fabs(H[i][j] - g[i] / xp[j]);
        for (i = 0; i < n; i++)
          free(H[i]);
        free(H);
        cout << yp - 1 / (1.0 + n) << "\\n";
        cout << errg << "\\n";
        cout << errh << "\\n";
        return 0;
      }
    EOS
    ENV.cxx11
    cxx_with_args = ENV.cxx.split + %W[
      test.cpp
      -I#{opt_include}
      -o test
      -L#{opt_lib} -ladolc
      -L#{Formula["colpack"].opt_lib} -lColPack
    ]
    system *cxx_with_args
    output = `./test`.split
    output.each { |val| assert val.to_f < 1.0e-8 }
  end
end
