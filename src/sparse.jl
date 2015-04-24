#utilities

# convert SparseChar {N,T,C} to cusparseOperation_t
function cusparseop(trans::SparseChar)
    if trans == 'N'
        return CUSPARSE_OPERATION_NON_TRANSPOSE
    end
    if trans == 'T'
        return CUSPARSE_OPERATION_TRANSPOSE
    end
    if trans == 'C'
        return CUSPARSE_OPERATION_CONJUGATE_TRANSPOSE
    end
    throw("unknown cusparse operation.")
end

# convert SparseChar {U,L} to cusparseFillMode_t
function cusparsefill(uplo::SparseChar)
    if uplo == 'U'
        return CUSPARSE_FILL_MODE_UPPER
    end
    if uplo == 'L'
        return CUSPARSE_FILL_MODE_LOWER
    end
    throw("unknown cusparse fill mode")
end

# convert SparseChar {U,N} to cusparseDiagType_t
function cusparsediag(diag::SparseChar)
    if diag == 'U'
        return CUSPARSE_DIAG_UNIT
    end
    if diag == 'N'
        return CUSPARSE_DIAG_NON_UNIT
    end
    throw("unknown cusparse diag mode")
end

# convert SparseChar {Z,O} to cusparseIndexBase_t
function cusparseindex(index::SparseChar)
    if index == 'Z'
        return CUSPARSE_INDEX_BASE_ZERO
    end
    if index == 'O'
        return CUSPARSE_INDEX_BASE_ONE
    end
    throw("unknown cusparse index base")
end

# convert SparseChar {R,C} to cusparseDirection_t
function cusparsedir(dir::SparseChar)
    if dir == 'R'
        return CUSPARSE_DIRECTION_ROW
    end
    if dir == 'C'
        return CUSPARSE_DIRECTION_COL
    end
    throw("unknown cusparse direction")
end

# type conversion
for (fname,elty) in ((:cusparseScsr2csc, :Float32),
                     (:cusparseDcsr2csc, :Float64),
                     (:cusparseCcsr2csc, :Complex64),
                     (:cusparseZcsr2csc, :Complex128))
    @eval begin
        function switch(csr::CudaSparseMatrixCSR{$elty})
            cuind = cusparseindex('O')
            m,n = csr.dims
            colPtr = CudaArray(zeros(Cint,n+1))
            rowVal = CudaArray(zeros(Cint,csr.nnz))
            nzVal = CudaArray(zeros($elty,csr.nnz))
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Cint, Cint, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{$elty}, Ptr{Cint},
                               Ptr{Cint}, cusparseAction_t, cusparseIndexBase_t),
                               cusparsehandle[1], m, n, csr.nnz, csr.nzVal,
                               csr.rowPtr, csr.colVal, nzVal, rowVal,
                               colPtr, CUSPARSE_ACTION_NUMERIC, cuind))
            csc = CudaSparseMatrixCSC(eltype(csr),colPtr,rowVal,nzVal,csr.nnz,csr.dims)
            csc
        end
        function switch(csc::CudaSparseMatrixCSC{$elty})
            cuind = cusparseindex('O')
            m,n = csc.dims
            rowPtr = CudaArray(zeros(Cint,m+1))
            colVal = CudaArray(zeros(Cint,csc.nnz))
            nzVal = CudaArray(zeros($elty,csc.nnz))
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Cint, Cint, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{$elty}, Ptr{Cint},
                               Ptr{Cint}, cusparseAction_t, cusparseIndexBase_t),
                               cusparsehandle[1], n, m, csc.nnz, csc.nzVal,
                               csc.colPtr, csc.rowVal, nzVal, colVal,
                               rowPtr, CUSPARSE_ACTION_NUMERIC, cuind))
            csr = CudaSparseMatrixCSR(eltype(csc),rowPtr,colVal,nzVal,csc.nnz,csc.dims)
            csr
        end
    end
end

for (cname,rname,elty) in ((:cusparseScsc2dense, :cusparseScsr2dense, :Float32),
                           (:cusparseDcsc2dense, :cusparseDcsr2dense, :Float64),
                           (:cusparseCcsc2dense, :cusparseCcsr2dense, :Complex64),
                           (:cusparseZcsc2dense, :cusparseZcsr2dense, :Complex128))
    @eval begin
        function full(csr::CudaSparseMatrixCSR{$elty},ind::SparseChar='O')
            cuind = cusparseindex(ind)
            m,n = csr.dims
            denseA = CudaArray(zeros($elty,m,n))
            lda = max(1,stride(denseA,2))
            cudesc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuind)
            statuscheck(ccall(($(string(rname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Cint,
                               Ptr{cusparseMatDescr_t}, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{$elty}, Ptr{Cint}),
                               cusparsehandle[1], m, n, &cudesc, csr.nzVal,
                               csr.rowPtr, csr.colVal, denseA, lda))
            denseA
        end
        function full(csc::CudaSparseMatrixCSC{$elty},ind::SparseChar='O')
            cuind = cusparseindex(ind)
            m,n = csc.dims
            denseA = CudaArray(zeros($elty,m,n))
            lda = max(1,stride(denseA,2))
            cudesc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuind)
            statuscheck(ccall(($(string(cname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Cint,
                               Ptr{cusparseMatDescr_t}, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{$elty}, Ptr{Cint}),
                               cusparsehandle[1], m, n, &cudesc, csc.nzVal,
                               csc.rowVal, csc.colPtr, denseA, lda))
            denseA
        end
    end
end

for (nname,cname,rname,elty) in ((:cusparseSnnz, :cusparseSdense2csc, :cusparseSdense2csr, :Float32),
                                 (:cusparseDnnz, :cusparseDdense2csc, :cusparseDdense2csr, :Float64),
                                 (:cusparseCnnz, :cusparseCdense2csc, :cusparseCdense2csr, :Complex64),
                                 (:cusparseZnnz, :cusparseZdense2csc, :cusparseZdense2csr, :Complex128))
    @eval begin
        function sparse(A::CudaMatrix{$elty},fmt::SparseChar='R',ind::SparseChar='O')
            cuind = cusparseindex(ind)
            cudir = cusparsedir(fmt)
            m,n = size(A)
            lda = max(1,stride(A,2))
            cudesc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuind)
            nnzRowCol = CudaArray(zeros(Cint, fmt == 'R' ? m : n))
            nnzTotal = Array(Cint,1)
            statuscheck(ccall(($(string(nname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, cusparseDirection_t,
                               Cint, Cint, Ptr{cusparseMatDescr_t}, Ptr{$elty},
                               Cint, Ptr{Cint}, Ptr{Cint}), cusparsehandle[1],
                               cudir, m, n, &cudesc, A, lda, nnzRowCol,
                               nnzTotal))
            nzVal = CudaArray(zeros($elty,nnzTotal[1]))
            if(fmt == 'R')
                rowPtr = CudaArray(zeros(Cint,m+1))
                colInd = CudaArray(zeros(Cint,nnzTotal[1]))
                statuscheck(ccall(($(string(rname)),libcusparse), cusparseStatus_t,
                                  (cusparseHandle_t, Cint, Cint,
                                   Ptr{cusparseMatDescr_t}, Ptr{$elty},
                                   Cint, Ptr{Cint}, Ptr{$elty}, Ptr{Cint},
                                   Ptr{Cint}), cusparsehandle[1], m, n, &cudesc, A,
                                   lda, nnzRowCol, nzVal, rowPtr, colInd))
                return CudaSparseMatrixCSR($elty,rowPtr,colInd,nzVal,nnzTotal[1],size(A))
            end
            if(fmt == 'C')
                colPtr = CudaArray(zeros(Cint,n+1))
                rowInd = CudaArray(zeros(Cint,nnzTotal[1]))
                statuscheck(ccall(($(string(cname)),libcusparse), cusparseStatus_t,
                                  (cusparseHandle_t, Cint, Cint,
                                   Ptr{cusparseMatDescr_t}, Ptr{$elty},
                                   Cint, Ptr{Cint}, Ptr{$elty}, Ptr{Cint},
                                   Ptr{Cint}), cusparsehandle[1], m, n, &cudesc, A,
                                   lda, nnzRowCol, nzVal, rowInd, colPtr))
                return CudaSparseMatrixCSC($elty,colPtr,rowInd,nzVal,nnzTotal[1],size(A))
            end
        end
    end
end

# Level 1 CUSPARSE functions

for (fname,elty) in ((:cusparseSaxpyi, :Float32),
                     (:cusparseDaxpyi, :Float64),
                     (:cusparseCaxpyi, :Complex64),
                     (:cusparseZaxpyi, :Complex128))
    @eval begin
        function axpyi!(alpha::$elty,
                        X::CudaSparseMatrixCSC{$elty},
                        Y::CudaVector{$elty},
                        index::SparseChar)
            cuind = cusparseindex(index)
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Ptr{$elty}, Ptr{$elty},
                               Ptr{Cint}, Ptr{$elty}, cusparseIndexBase_t),
                              cusparsehandle[1], X.nnz, [alpha], X.nzVal, X.rowVal,
                              Y, cuind))
            Y
        end
        function axpyi(alpha::$elty,
                       X::CudaSparseMatrixCSC{$elty},
                       Y::CudaVector{$elty},
                       index::SparseChar)
            axpyi!(alpha,X,copy(Y),index)
        end
        function axpyi(X::CudaSparseMatrixCSC{$elty},
                       Y::CudaVector{$elty},
                       index::SparseChar)
            axpyi!(one($elty),X,copy(Y),index)
        end
    end
end

for (jname,fname,elty) in ((:doti, :cusparseSdoti, :Float32),
                           (:doti, :cusparseDdoti, :Float64),
                           (:doti, :cusparseCdoti, :Complex64),
                           (:doti, :cusparseZdoti, :Complex128),
                           (:dotci, :cusparseCdotci, :Complex64),
                           (:dotci, :cusparseZdotci, :Complex128))
    @eval begin
        function $jname(X::CudaSparseMatrixCSC{$elty},
                        Y::CudaVector{$elty},
                        index::SparseChar)
            dot = Array($elty,1)
            cuind = cusparseindex(index)
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Ptr{$elty}, Ptr{Cint},
                               Ptr{$elty}, Ptr{$elty}, cusparseIndexBase_t),
                              cusparsehandle[1], X.nnz, X.nzVal, X.rowVal,
                              Y, dot, cuind))
            return dot[1]
        end
    end
end

for (fname,elty) in ((:cusparseSgthr, :Float32),
                     (:cusparseDgthr, :Float64),
                     (:cusparseCgthr, :Complex64),
                     (:cusparseZgthr, :Complex128))
    @eval begin
        function gthr!(X::CudaSparseMatrixCSC{$elty},
                      Y::CudaVector{$elty},
                      index::SparseChar)
            cuind = cusparseindex(index)
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Ptr{$elty}, Ptr{$elty},
                               Ptr{Cint}, cusparseIndexBase_t), cusparsehandle[1],
                              X.nnz, Y, X.nzVal, X.rowVal, cuind))
            X
        end
        function gthr(X::CudaSparseMatrixCSC{$elty},
                      Y::CudaVector{$elty},
                      index::SparseChar)
            gthr!(copy(X),Y,index)
        end
    end
end

for (fname,elty) in ((:cusparseSgthrz, :Float32),
                     (:cusparseDgthrz, :Float64),
                     (:cusparseCgthrz, :Complex64),
                     (:cusparseZgthrz, :Complex128))
    @eval begin
        function gthrz!(X::CudaSparseMatrixCSC{$elty},
                        Y::CudaVector{$elty},
                        index::SparseChar)
            cuind = cusparseindex(index)
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Ptr{$elty}, Ptr{$elty},
                               Ptr{Cint}, cusparseIndexBase_t), cusparsehandle[1],
                              X.nnz, Y, X.nzVal, X.rowVal, cuind))
            X,Y
        end
        function gthrz(X::CudaSparseMatrixCSC{$elty},
                       Y::CudaVector{$elty},
                       index::SparseChar)
            gthrz!(copy(X),copy(Y),index)
        end
    end
end

for (fname,elty) in ((:cusparseSroti, :Float32),
                     (:cusparseDroti, :Float64))
    @eval begin
        function roti!(X::CudaSparseMatrixCSC{$elty},
                       Y::CudaVector{$elty},
                       c::$elty,
                       s::$elty,
                       index::SparseChar)
            cuind = cusparseindex(index)
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Ptr{$elty}, Ptr{$Cint},
                               Ptr{$elty}, Ptr{$elty}, Ptr{$elty}, cusparseIndexBase_t),
                              cusparsehandle[1], X.nnz, X.nzVal, X.rowVal, Y, [c], [s], cuind))
            X,Y
        end
        function roti(X::CudaSparseMatrixCSC{$elty},
                      Y::CudaVector{$elty},
                      c::$elty,
                      s::$elty,
                      index::SparseChar)
            roti!(copy(X),copy(Y),c,s,index)
        end
    end
end

for (fname,elty) in ((:cusparseSsctr, :Float32),
                     (:cusparseDsctr, :Float64),
                     (:cusparseCsctr, :Complex64),
                     (:cusparseZsctr, :Complex128))
    @eval begin
        function sctr!(X::CudaSparseMatrixCSC{$elty},
                       Y::CudaVector{$elty},
                       index::SparseChar)
            cuind = cusparseindex(index)
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Ptr{$elty}, Ptr{Cint},
                               Ptr{$elty}, cusparseIndexBase_t),
                              cusparsehandle[1], X.nnz, X.nzVal, X.rowVal,
                              Y, cuind))
            Y
        end
        function sctr(X::CudaSparseMatrixCSC{$elty},
                      index::SparseChar)
            sctr!(X,CudaArray(zeros($elty,X.dims[1])),index)
        end
    end
end

## level 2 functions

for (fname,elty) in ((:cusparseScsrmv, :Float32),
                     (:cusparseDcsrmv, :Float64),
                     (:cusparseCcsrmv, :Complex64),
                     (:cusparseZcsrmv, :Complex128))
    @eval begin
        function csrmv!(transa::SparseChar,
                        alpha::$elty,
                        A::CudaSparseMatrixCSR{$elty},
                        X::CudaVector{$elty},
                        beta::$elty,
                        Y::CudaVector{$elty},
                        index::SparseChar)
            cutransa = cusparseop(transa)
            cuind = cusparseindex(index)
            cudesc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuind)
            m,n = A.dims
            if( transa == 'N' && (length(X) != n || length(Y) != m) )
                throw(DimensionMismatch(""))
            end
            if( (transa == 'T' || transa == 'C') && (length(X) != m || length(Y) != n) )
                throw(DimensionMismatch(""))
            end
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, cusparseOperation_t, Cint,
                               Cint, Cint, Ptr{$elty}, Ptr{cusparseMatDescr_t},
                               Ptr{$elty}, Ptr{Cint}, Ptr{Cint}, Ptr{$elty},
                               Ptr{$elty}, Ptr{$elty}), cusparsehandle[1],
                               cutransa, m, n, A.nnz, [alpha], &cudesc, A.nzVal,
                               A.rowPtr, A.colVal, X, [beta], Y))
            Y
        end
        function csrmv(transa::SparseChar,
                       alpha::$elty,
                       A::CudaSparseMatrixCSR{$elty},
                       X::CudaVector{$elty},
                       beta::$elty,
                       Y::CudaVector{$elty},
                       index::SparseChar)
            csrmv!(transa,alpha,A,X,beta,copy(Y),index)
        end
        function csrmv(transa::SparseChar,
                       alpha::$elty,
                       A::CudaSparseMatrixCSR{$elty},
                       X::CudaVector{$elty},
                       Y::CudaVector{$elty},
                       index::SparseChar)
            csrmv(transa,alpha,A,X,one($elty),Y,index)
        end
        function csrmv(transa::SparseChar,
                       A::CudaSparseMatrixCSR{$elty},
                       X::CudaVector{$elty},
                       beta::$elty,
                       Y::CudaVector{$elty},
                       index::SparseChar)
            csrmv(transa,one($elty),A,X,beta,Y,index)
        end
        function csrmv(transa::SparseChar,
                       A::CudaSparseMatrixCSR{$elty},
                       X::CudaVector{$elty},
                       Y::CudaVector{$elty},
                       index::SparseChar)
            csrmv(transa,one($elty),A,X,one($elty),Y,index)
        end
        function csrmv(transa::SparseChar,
                       alpha::$elty,
                       A::CudaSparseMatrixCSR{$elty},
                       X::CudaVector{$elty},
                       index::SparseChar)
            csrmv(transa,alpha,A,X,zero($elty),CudaArray(zeros($elty,size(A)[1])),index)
        end
        function csrmv(transa::SparseChar,
                       A::CudaSparseMatrixCSR{$elty},
                       X::CudaVector{$elty},
                       index::SparseChar)
            csrmv(transa,one($elty),A,X,zero($elty),CudaArray(zeros($elty,size(A)[1])),index)
        end
    end
end

## level 3 functions

for (fname,elty) in ((:cusparseScsrmm, :Float32),
                     (:cusparseDcsrmm, :Float64),
                     (:cusparseCcsrmm, :Complex64),
                     (:cusparseZcsrmm, :Complex128))
    @eval begin
        function csrmm!(transa::SparseChar,
                        alpha::$elty,
                        A::CudaSparseMatrixCSR{$elty},
                        B::CudaMatrix{$elty},
                        beta::$elty,
                        C::CudaMatrix{$elty},
                        index::SparseChar)
            cutransa = cusparseop(transa)
            cuind = cusparseindex(index)
            cudesc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuind)
            m,k = A.dims
            n = size(C)[2]
            if( transa == 'N' && (size(B) != (k,n) || size(C) != (m,n)) )
                throw(DimensionMismatch(""))
            end
            if( (transa == 'T' || transa == 'C') && (size(B) != (m,n) || size(C) != (k,n)) )
                throw(DimensionMismatch(""))
            end
            ldb = max(1,stride(B,2))
            ldc = max(1,stride(C,2))
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, cusparseOperation_t, Cint, Cint,
                               Cint, Cint, Ptr{$elty}, Ptr{cusparseMatDescr_t},
                               Ptr{$elty}, Ptr{Cint}, Ptr{Cint}, Ptr{$elty},
                               Cint, Ptr{$elty}, Ptr{$elty}, Cint),
                               cusparsehandle[1], cutransa, m, n, k, A.nnz,
                               [alpha], &cudesc, A.nzVal,A.rowPtr, A.colVal, B,
                               ldb, [beta], C, ldc))
            C
        end
        function csrmm(transa::SparseChar,
                       alpha::$elty,
                       A::CudaSparseMatrixCSR{$elty},
                       B::CudaMatrix{$elty},
                       beta::$elty,
                       C::CudaMatrix{$elty},
                       index::SparseChar)
            csrmm!(transa,alpha,A,B,beta,copy(C),index)
        end
        function csrmm(transa::SparseChar,
                       A::CudaSparseMatrixCSR{$elty},
                       B::CudaMatrix{$elty},
                       beta::$elty,
                       C::CudaMatrix{$elty},
                       index::SparseChar)
            csrmm(transa,one($elty),A,B,beta,C,index)
        end
        function csrmm(transa::SparseChar,
                       A::CudaSparseMatrixCSR{$elty},
                       B::CudaMatrix{$elty},
                       C::CudaMatrix{$elty},
                       index::SparseChar)
            csrmm(transa,one($elty),A,B,one($elty),C,index)
        end
        function csrmm(transa::SparseChar,
                       alpha::$elty,
                       A::CudaSparseMatrixCSR{$elty},
                       B::CudaMatrix{$elty},
                       index::SparseChar)
            m = transa == 'N' ? size(A)[1] : size(A)[2]
            csrmm!(transa,alpha,A,B,zero($elty),CudaArray(zeros($elty,(m,size(B)[2]))),index)
        end
        function csrmm(transa::SparseChar,
                       A::CudaSparseMatrixCSR{$elty},
                       B::CudaMatrix{$elty},
                       index::SparseChar)
            m = transa == 'N' ? size(A)[1] : size(A)[2]
            csrmm!(transa,one($elty),A,B,zero($elty),CudaArray(zeros($elty,(m,size(B)[2]))),index)
        end
    end
end

for (fname,elty) in ((:cusparseScsrmm2, :Float32),
                     (:cusparseDcsrmm2, :Float64),
                     (:cusparseCcsrmm2, :Complex64),
                     (:cusparseZcsrmm2, :Complex128))
    @eval begin
        function csrmm2!(transa::SparseChar,
                        transb::SparseChar,
                        alpha::$elty,
                        A::CudaSparseMatrixCSR{$elty},
                        B::CudaMatrix{$elty},
                        beta::$elty,
                        C::CudaMatrix{$elty},
                        index::SparseChar)
            cutransa = cusparseop(transa)
            cutransb = cusparseop(transb)
            cuind = cusparseindex(index)
            cudesc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuind)
            m,k = A.dims
            n = size(C)[2]
            if( transa == 'N' && ( (transb == 'N' ? size(B) != (k,n) : size(B) != (n,k)) || size(C) != (m,n)) )
                throw(DimensionMismatch(""))
            end
            if( (transa == 'T' || transa == 'C') && ((transb == 'N' ? size(B) != (m,n) : size(B) != (n,m)) || size(C) != (k,n)) )
                throw(DimensionMismatch(""))
            end
            ldb = max(1,stride(B,2))
            ldc = max(1,stride(C,2))
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, cusparseOperation_t,
                               cusparseOperation_t, Cint, Cint, Cint, Cint,
                               Ptr{$elty}, Ptr{cusparseMatDescr_t}, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{$elty}, Cint,
                               Ptr{$elty}, Ptr{$elty}, Cint), cusparsehandle[1],
                               cutransa, cutransb, m, n, k, A.nnz, [alpha], &cudesc,
                               A.nzVal, A.rowPtr, A.colVal, B, ldb, [beta], C, ldc))
            C
        end
        function csrmm2(transa::SparseChar,
                        transb::SparseChar,
                        alpha::$elty,
                        A::CudaSparseMatrixCSR{$elty},
                        B::CudaMatrix{$elty},
                        beta::$elty,
                        C::CudaMatrix{$elty},
                        index::SparseChar)
            csrmm2!(transa,transb,alpha,A,B,beta,copy(C),index)
        end
        function csrmm2(transa::SparseChar,
                        transb::SparseChar,
                        A::CudaSparseMatrixCSR{$elty},
                        B::CudaMatrix{$elty},
                        beta::$elty,
                        C::CudaMatrix{$elty},
                        index::SparseChar)
            csrmm2(transa,transb,one($elty),A,B,beta,C,index)
        end
        function csrmm2(transa::SparseChar,
                        transb::SparseChar,
                        A::CudaSparseMatrixCSR{$elty},
                        B::CudaMatrix{$elty},
                        C::CudaMatrix{$elty},
                        index::SparseChar)
            csrmm2(transa,transb,one($elty),A,B,one($elty),C,index)
        end
        function csrmm2(transa::SparseChar,
                        transb::SparseChar,
                        alpha::$elty,
                        A::CudaSparseMatrixCSR{$elty},
                        B::CudaMatrix{$elty},
                        index::SparseChar)
            m = transa == 'N' ? size(A)[1] : size(A)[2]
            n = transb == 'N' ? size(B)[2] : size(B)[1]
            csrmm2(transa,transb,alpha,A,B,zero($elty),CudaArray(zeros($elty,(m,n))),index)
        end
        function csrmm2(transa::SparseChar,
                        transb::SparseChar,
                        A::CudaSparseMatrixCSR{$elty},
                        B::CudaMatrix{$elty},
                        index::SparseChar)
            m = transa == 'N' ? size(A)[1] : size(A)[2]
            n = transb == 'N' ? size(B)[2] : size(B)[1]
            csrmm2(transa,transb,one($elty),A,B,zero($elty),CudaArray(zeros($elty,(m,n))),index)
        end
    end
end

# extensions

for (fname,elty) in ((:cusparseScsrgeam, :Float32),
                     (:cusparseDcsrgeam, :Float64),
                     (:cusparseCcsrgeam, :Complex64),
                     (:cusparseZcsrgeam, :Complex128))
    @eval begin
        function geam(alpha::$elty,
                      A::CudaSparseMatrixCSR{$elty},
                      beta::$elty,
                      B::CudaSparseMatrixCSR{$elty},
                      indexA::SparseChar,
                      indexB::SparseChar,
                      indexC::SparseChar)
            cuinda = cusparseindex(indexA)
            cuindb = cusparseindex(indexB)
            cuindc = cusparseindex(indexB)
            cudesca = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuinda)
            cudescb = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuindb)
            cudescc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuindc)
            mA,nA = A.dims
            mB,nB = B.dims
            if( (mA != mB) || (nA != nB) )
                throw(DimensionMismatch(""))
            end
            nnzC = Array(Cint,1)
            rowPtrC = CudaArray(zeros(Cint,mA+1))
            statuscheck(ccall((:cusparseXcsrgeamNnz,libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Cint,
                               Ptr{cusparseMatDescr_t}, Cint, Ptr{Cint},
                               Ptr{Cint}, Ptr{cusparseMatDescr_t}, Cint, Ptr{Cint},
                               Ptr{Cint}, Ptr{cusparseMatDescr_t}, Ptr{Cint},
                               Ptr{Cint}), cusparsehandle[1], mA, nA, &cudesca,
                               A.nnz, A.rowPtr, A.colVal, &cudescb, B.nnz,
                               B.rowPtr, B.colVal, &cudescc, rowPtrC, nnzC))
            nnz = nnzC[1]
            C = CudaSparseMatrixCSR($elty, rowPtrC, CudaArray(zeros(Cint,nnz)), CudaArray(zeros($elty,nnz)), nnz, A.dims)
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, Cint, Cint, Ptr{$elty},
                               Ptr{cusparseMatDescr_t}, Cint, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{$elty},
                               Ptr{cusparseMatDescr_t}, Cint, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{cusparseMatDescr_t},
                               Ptr{$elty}, Ptr{Cint}, Ptr{Cint}),
                              cusparsehandle[1], mA, nA, [alpha], &cudesca,
                              A.nnz, A.nzVal, A.rowPtr, A.colVal, [beta],
                              &cudescb, B.nnz, B.nzVal, B.rowPtr, B.colVal,
                              &cudescc, C.nzVal, C.rowPtr, C.colVal))
            C
        end
        function geam(alpha::$elty,
                      A::CudaSparseMatrixCSR{$elty},
                      B::CudaSparseMatrixCSR{$elty},
                      indexA::SparseChar,
                      indexB::SparseChar,
                      indexC::SparseChar)
            geam(alpha,A,one($elty),B,indexA,indexB,indexC)
        end
        function geam(A::CudaSparseMatrixCSR{$elty},
                      beta::$elty,
                      B::CudaSparseMatrixCSR{$elty},
                      indexA::SparseChar,
                      indexB::SparseChar,
                      indexC::SparseChar)
            geam(one($elty),A,beta,B,indexA,indexB,indexC)
        end
        function geam(A::CudaSparseMatrixCSR{$elty},
                      B::CudaSparseMatrixCSR{$elty},
                      indexA::SparseChar,
                      indexB::SparseChar,
                      indexC::SparseChar)
            geam(one($elty),A,one($elty),B,indexA,indexB,indexC)
        end
    end
end

for (fname,elty) in ((:cusparseScsrgemm, :Float32),
                     (:cusparseDcsrgemm, :Float64),
                     (:cusparseCcsrgemm, :Complex64),
                     (:cusparseZcsrgemm, :Complex128))
    @eval begin
        function gemm(transa::SparseChar,
                      transb::SparseChar,
                      A::CudaSparseMatrixCSR{$elty},
                      B::CudaSparseMatrixCSR{$elty},
                      indexA::SparseChar,
                      indexB::SparseChar,
                      indexC::SparseChar)
            cutransa = cusparseop(transb)
            cutransb = cusparseop(transa)
            cuinda = cusparseindex(indexA)
            cuindb = cusparseindex(indexB)
            cuindc = cusparseindex(indexB)
            cudesca = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuinda)
            cudescb = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuindb)
            cudescc = cusparseMatDescr_t(CUSPARSE_MATRIX_TYPE_GENERAL, CUSPARSE_FILL_MODE_LOWER, CUSPARSE_DIAG_TYPE_NON_UNIT, cuindc)
            m,k  = transa == 'N' ? A.dims : (A.dims[2],A.dims[1])
            kB,n = transb == 'N' ? B.dims : (B.dims[2],B.dims[1])
            if( (k != kB) )
                throw(DimensionMismatch(""))
            end
            nnzC = Array(Cint,1)
            rowPtrC = CudaArray(zeros(Cint,m + 1))
            statuscheck(ccall((:cusparseXcsrgemmNnz,libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, cusparseOperation_t,
                               cusparseOperation_t, Cint, Cint, Cint,
                               Ptr{cusparseMatDescr_t}, Cint, Ptr{Cint},
                               Ptr{Cint}, Ptr{cusparseMatDescr_t}, Cint, Ptr{Cint},
                               Ptr{Cint}, Ptr{cusparseMatDescr_t}, Ptr{Cint},
                               Ptr{Cint}), cusparsehandle[1], cutransa, cutransb,
                               m, n, k, &cudesca, A.nnz, A.rowPtr, A.colVal,
                               &cudescb, B.nnz, B.rowPtr, B.colVal, &cudescc,
                               rowPtrC, nnzC))
            nnz = nnzC[1]
            C = CudaSparseMatrixCSR($elty, rowPtrC, CudaArray(zeros(Cint,nnz)), CudaArray(zeros($elty,nnz)), nnz, (m,n))
            statuscheck(ccall(($(string(fname)),libcusparse), cusparseStatus_t,
                              (cusparseHandle_t, cusparseOperation_t,
                               cusparseOperation_t, Cint, Cint, Cint,
                               Ptr{cusparseMatDescr_t}, Cint, Ptr{$elty},
                               Ptr{Cint}, Ptr{Cint}, Ptr{cusparseMatDescr_t},
                               Cint, Ptr{$elty}, Ptr{Cint}, Ptr{Cint},
                               Ptr{cusparseMatDescr_t}, Ptr{$elty}, Ptr{Cint},
                               Ptr{Cint}), cusparsehandle[1], cutransa,
                               cutransb, m, n, k, &cudesca, A.nnz, A.nzVal,
                               A.rowPtr, A.colVal, &cudescb, B.nnz, B.nzVal,
                               B.rowPtr, B.colVal, &cudescc, C.nzVal,
                               C.rowPtr, C.colVal))
            C
        end
    end
end